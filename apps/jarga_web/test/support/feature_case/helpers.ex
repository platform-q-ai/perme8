defmodule JargaWeb.FeatureCase.Helpers do
  @moduledoc """
  Helper functions for Wallaby feature tests.
  """

  import Wallaby.Browser
  import Wallaby.Query

  alias Phoenix.Ecto.SQL.Sandbox
  alias Wallaby.Element

  @doc """
  Gets a persistent test user by key.

  Available test users: :alice, :bob, :charlie

  ## Examples

      user = get_test_user(:alice)
      session |> log_in_user(user)

  """
  def get_test_user(key) when is_atom(key) do
    Jarga.TestUsers.get_user(key)
  end

  @doc """
  Logs in a user via the login page.

  Uses the actual login flow to ensure proper authentication in E2E tests.
  """
  def log_in_user(session, user) do
    password = Jarga.TestUsers.get_password(user_key_from_email(user.email))

    session
    |> visit("/users/log-in")
    # Wait for LiveView to fully mount and stabilize
    |> assert_has(css("#login_form_password"))
    |> then(fn session ->
      # Delay for LiveView to stabilize after mount and get DB access
      Process.sleep(500)
      session
    end)
    |> fill_in(css("#login_form_password_email"), with: user.email)
    |> fill_in(css("#login_form_password_password"), with: password)
    |> click(button("Log in and stay logged in"))
  end

  # Helper to get user key from email
  defp user_key_from_email("alice@example.com"), do: :alice
  defp user_key_from_email("bob@example.com"), do: :bob
  defp user_key_from_email("charlie@example.com"), do: :charlie
  # Default fallback
  defp user_key_from_email(_), do: :alice

  @doc """
  Opens a document in the editor for the given user.

  Assumes the user is already logged in.

  Waits for the Milkdown editor to initialize, which happens asynchronously
  after the LiveView mounts and the MilkdownEditor hook runs.
  """
  def open_document(session, workspace_slug, document_slug) do
    session
    |> visit("/app/workspaces/#{workspace_slug}/documents/#{document_slug}")
    # Wait for LiveView to connect - brief pause for WebSocket
    |> then(fn s ->
      Process.sleep(500)
      s
    end)
    # Wait for the editor container (from LiveView) with retries
    |> wait_for_editor_container()
    # Wait for JavaScript to initialize Milkdown - it adds .milkdown class
    # This may take a moment as it loads the editor bundle
    |> wait_for_milkdown_editor()
    |> take_screenshot(name: "after_navigate_to_document")
  end

  @doc """
  Waits for the editor container element to appear.

  Retries several times with increasing delays to handle slow page loads.
  """
  def wait_for_editor_container(session, attempts \\ 5) do
    session
    |> assert_has(css("#editor-container", visible: true))
  rescue
    Wallaby.ExpectationNotMetError ->
      if attempts > 0 do
        # Wait longer and retry
        Process.sleep(1000)
        wait_for_editor_container(session, attempts - 1)
      else
        # Take screenshot for debugging before re-raising
        session |> take_screenshot(name: "editor_container_not_found")

        reraise Wallaby.ExpectationNotMetError,
                [message: "Expected to find #editor-container after multiple retries"],
                __STACKTRACE__
      end
  end

  @doc """
  Waits for LiveView to be ready by checking for phx-socket connection.
  Uses simple polling instead of Promises for better compatibility.
  """
  def wait_for_liveview_ready(session, timeout \\ 10_000) do
    wait_until_ready(session, timeout, System.monotonic_time(:millisecond))
  end

  defp wait_until_ready(session, timeout, start_time) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed > timeout do
      # Timeout - just proceed (page might be ready anyway)
      Process.sleep(500)
      session
    else
      # Check if page is ready using JavaScript
      ready? =
        try do
          Wallaby.Browser.execute_script(session, """
            var main = document.querySelector('[data-phx-main]');
            var socket = window.liveSocket;
            return !!(main && socket);
          """)

          # execute_script returns session, so we need a different approach
          true
        rescue
          _ -> false
        end

      if ready? do
        # Additional wait for socket to stabilize
        Process.sleep(300)
        session
      else
        # Wait and retry
        Process.sleep(200)
        wait_until_ready(session, timeout, start_time)
      end
    end
  end

  @doc """
  Waits for the Milkdown editor to fully initialize.

  Milkdown initialization is async - after the hook mounts, it creates the Editor
  which adds the .milkdown class to the container. We poll for this class.
  """
  def wait_for_milkdown_editor(session, timeout \\ 10_000) do
    session
    |> execute_script("""
      return new Promise((resolve, reject) => {
        const startTime = Date.now();
        const timeout = #{timeout};
        
        function checkForMilkdown() {
          // Check for .milkdown class (added by Milkdown)
          const milkdown = document.querySelector('.milkdown');
          // Also check for ProseMirror (inner editor)
          const prosemirror = document.querySelector('.ProseMirror');
          
          if (milkdown || prosemirror) {
            resolve(true);
            return;
          }
          
          if (Date.now() - startTime > timeout) {
            // Get debug info about what's on the page
            const container = document.querySelector('#editor-container');
            const containerHTML = container ? container.innerHTML.substring(0, 200) : 'no container';
            reject(new Error('Milkdown editor not found after ' + timeout + 'ms. Container: ' + containerHTML));
            return;
          }
          
          setTimeout(checkForMilkdown, 100);
        }
        
        checkForMilkdown();
      });
    """)
    |> then(fn session ->
      # Brief additional wait for editor to stabilize
      Process.sleep(200)
      session
    end)
  end

  @doc """
  Types text into the Milkdown editor.

  Clicks in the editor to focus it, then types the text.
  """
  def type_in_editor(session, text) do
    session
    |> click_in_editor()
    |> then(fn session ->
      # Send keys directly to the focused editor
      send_keys(session, [text])
    end)
  end

  @doc """
  Clicks inside the Milkdown editor to focus it and initialize awareness.

  This is necessary for collaborative cursor tracking to work properly.
  The click triggers ProseMirror's selection update, which sets the awareness state.

  NOTE: This directly focuses the ProseMirror editor and sets selection at position 0.
  """
  def click_in_editor(session) do
    session
    |> assert_has(css("#editor-container"))
    |> execute_script("""
      // Find the ProseMirror editor within the container
      const container = document.querySelector('#editor-container');
      const pmEditor = container ? container.querySelector('.ProseMirror') : null;
      
      if (pmEditor) {
        // Focus the editor
        pmEditor.focus();
        
        // Set cursor to start of document to trigger selection update
        const event = new MouseEvent('click', {
          view: window,
          bubbles: true,
          cancelable: true,
          clientX: 10,
          clientY: 10
        });
        pmEditor.dispatchEvent(event);
      }
    """)
    |> then(fn session ->
      # Brief wait for awareness to initialize
      Process.sleep(200)
      session
    end)
  end

  @doc """
  Gets the text content from the Milkdown editor.

  Filters out remote cursor labels to get only the actual document content.
  Uses either .milkdown or .ProseMirror selector (both work).
  """
  def get_editor_content(session) do
    # Try .ProseMirror first (more reliable), fallback to .milkdown
    text =
      try do
        session
        |> find(css("#editor-container .ProseMirror"))
        |> Element.text()
      rescue
        _ ->
          session
          |> find(css(".milkdown"))
          |> Element.text()
      end

    # Remove cursor labels which appear as "Name N." patterns
    # Cursor labels follow the pattern "Firstname L." (name with one-letter last name)
    text
    |> String.split("\n")
    |> Enum.reject(fn line ->
      # Remove lines that are just cursor labels (e.g., "Bob B.", "Alice A.")
      String.match?(line, ~r/^[A-Z][a-z]+ [A-Z]\.$/)
    end)
    |> Enum.join("\n")
  end

  @doc """
  Waits for text to appear in the editor.

  Uses JavaScript polling to check for text in ProseMirror editor,
  which is more reliable than CSS selectors for dynamic content.
  """
  def wait_for_text_in_editor(session, text, timeout \\ 5000) do
    escaped_text = String.replace(text, "'", "\\'")

    session
    |> execute_script("""
      return new Promise((resolve, reject) => {
        const startTime = Date.now();
        const timeout = #{timeout};
        const searchText = '#{escaped_text}';
        
        function checkForText() {
          const editor = document.querySelector('#editor-container .ProseMirror') ||
                        document.querySelector('.milkdown');
          
          if (editor && editor.textContent.includes(searchText)) {
            resolve(true);
            return;
          }
          
          if (Date.now() - startTime > timeout) {
            const content = editor ? editor.textContent.substring(0, 200) : 'no editor';
            reject(new Error('Text not found: "' + searchText + '". Content: ' + content));
            return;
          }
          
          setTimeout(checkForText, 100);
        }
        
        checkForText();
      });
    """)
  end

  @doc """
  Simulates keyboard shortcut (e.g., undo, redo).

  Examples:
    - Undo: send_shortcut(session, [:control, "z"])
    - Redo: send_shortcut(session, [:control, :shift, "z"])
  """
  def send_shortcut(session, keys) do
    session
    |> send_keys(keys)
  end

  @doc """
  Triggers undo in the Milkdown editor.

  Uses WebDriver Actions API to send Ctrl+Z properly.
  """
  def undo(session) do
    session
    |> click_in_editor()
    |> then(fn session ->
      # Use execute_script to send proper keyboard combination
      execute_script(session, """
        const el = document.querySelector('#editor-container .ProseMirror');
        if (el) {
          el.focus();
          // Create and dispatch a proper keyboard event
          const event = new KeyboardEvent('keydown', {
            key: 'z',
            code: 'KeyZ',
            keyCode: 90,
            which: 90,
            ctrlKey: true,
            metaKey: false,
            bubbles: true,
            cancelable: true,
            composed: true
          });
          el.dispatchEvent(event);
        }
      """)
    end)
    |> then(fn session ->
      # Brief wait for undo operation to complete
      Process.sleep(300)
      session
    end)
  end

  @doc """
  Triggers redo in the Milkdown editor.

  Uses WebDriver Actions API to send Ctrl+Y properly.
  """
  def redo(session) do
    session
    |> click_in_editor()
    |> then(fn session ->
      # Use execute_script to send proper keyboard combination
      execute_script(session, """
        const el = document.querySelector('#editor-container .ProseMirror');
        if (el) {
          el.focus();
          // Create and dispatch a proper keyboard event
          const event = new KeyboardEvent('keydown', {
            key: 'y',
            code: 'KeyY',
            keyCode: 89,
            which: 89,
            ctrlKey: true,
            metaKey: false,
            bubbles: true,
            cancelable: true,
            composed: true
          });
          el.dispatchEvent(event);
        }
      """)
    end)
    |> then(fn session ->
      # Brief wait for redo operation to complete
      Process.sleep(300)
      session
    end)
  end

  @doc """
  Opens a new browser session (for multi-user tests).

  The new session will share the database transaction with the test process.
  """
  def new_session do
    metadata = Sandbox.metadata_for(Jarga.Repo, self())
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    session
  end

  @doc """
  Refreshes the current page.
  """
  def refresh_page(session) do
    session
    |> execute_script("window.location.reload();")
    |> Wallaby.Browser.assert_has(css("body"))
  end

  @doc """
  Waits for an element to appear on the page.
  """
  def wait_for_element(session, query, _timeout \\ 5000) do
    session
    |> Wallaby.Browser.assert_has(query)
  end

  @doc """
  Takes a screenshot for debugging purposes.

  Screenshots are saved to the configured screenshot directory.
  """
  def debug_screenshot(session, name \\ "debug") do
    session
    |> take_screenshot(name: name)
  end

  @doc """
  Saves the current page HTML for debugging purposes.

  HTML is saved to tmp/html/ directory.
  """
  def save_html(session, name \\ "debug") do
    session
    |> then(fn session ->
      # Get HTML using page_source
      html = Wallaby.Browser.page_source(session)

      # Ensure tmp/html directory exists
      File.mkdir_p!("tmp/html")

      # Save HTML to file
      file_path = "tmp/html/#{name}.html"
      File.write!(file_path, html)

      IO.puts("💾 Saved HTML to #{file_path}")

      session
    end)
  end

  @doc """
  Clicks a checkbox element.
  """
  def click_checkbox(session, selector) do
    session
    |> click(css(selector))
  end

  @doc """
  Waits for a checkbox to be in the checked state.
  """
  def wait_for_checkbox_checked(session, selector, _timeout \\ 5000) do
    query = css("#{selector}:checked", count: 1)

    session
    |> Wallaby.Browser.assert_has(query)
  end

  @doc """
  Waits for a checkbox to be in the unchecked state.
  """
  def wait_for_checkbox_unchecked(session, selector, _timeout \\ 5000) do
    query = css("#{selector}:not(:checked)", count: 1)

    session
    |> Wallaby.Browser.assert_has(query)
  end

  @doc """
  Waits for a cursor element to appear (for multi-user cursor tests).

  Note: The remote user must click in their editor before their cursor will appear.
  This is because Yjs awareness only broadcasts cursor position after a selection is set.

  IMPORTANT: Remote cursors are rendered in ProseMirror's virtual DOM (decorations),
  not directly in the HTML DOM. We use JavaScript to query getElementsByClassName
  instead of CSS selectors.
  """
  def wait_for_cursor(session, user_name, timeout \\ 5000) do
    # Remote cursors exist in ProseMirror decorations, accessible via getElementsByClassName
    # We need to poll with JavaScript since they're not in the regular DOM
    session
    |> execute_script("""
      return new Promise((resolve, reject) => {
        const startTime = Date.now();
        const timeout = #{timeout};
        
        function checkForCursor() {
          const cursors = document.getElementsByClassName('remote-cursor');
          for (let cursor of cursors) {
            if (cursor.getAttribute('data-user-name') === '#{user_name}') {
              resolve(true);
              return;
            }
          }
          
          if (Date.now() - startTime > timeout) {
            reject(new Error('Cursor not found for user: #{user_name}'));
            return;
          }
          
          setTimeout(checkForCursor, 100);
        }
        
        checkForCursor();
      });
    """)
    |> then(fn session ->
      # Return session for chaining
      session
    end)
  end

  @doc """
  Waits for a cursor element to disappear.

  Polls using JavaScript getElementsByClassName since cursors are in ProseMirror decorations.
  """
  def wait_for_cursor_to_disappear(session, user_name, timeout \\ 3000) do
    session
    |> execute_script("""
      return new Promise((resolve, reject) => {
        const startTime = Date.now();
        const timeout = #{timeout};
        
        function checkCursorGone() {
          const cursors = document.getElementsByClassName('remote-cursor');
          let found = false;
          
          for (let cursor of cursors) {
            if (cursor.getAttribute('data-user-name') === '#{user_name}') {
              found = true;
              break;
            }
          }
          
          if (!found) {
            resolve(true);
            return;
          }
          
          if (Date.now() - startTime > timeout) {
            reject(new Error('Cursor still present for user: #{user_name}'));
            return;
          }
          
          setTimeout(checkCursorGone, 100);
        }
        
        checkCursorGone();
      });
    """)
    |> then(fn session ->
      # Return session for chaining
      session
    end)
  end

  @doc """
  Ends a browser session.

  Use this to clean up secondary sessions in multi-user tests.
  """
  def close_session(session) do
    Wallaby.end_session(session)
  end

  @doc """
  Pastes text into the editor using clipboard simulation.

  Note: This uses JavaScript to insert text as if it was pasted.
  """
  def paste_in_editor(session, text) do
    escaped_text = String.replace(text, "'", "\\'")

    session
    |> click_in_editor()
    |> execute_script("""
      const editor = document.querySelector('#editor-container .ProseMirror') ||
                    document.querySelector('.milkdown');
      if (editor) {
        const event = new ClipboardEvent('paste', {
          clipboardData: new DataTransfer()
        });
        event.clipboardData.setData('text/plain', '#{escaped_text}');
        editor.dispatchEvent(event);
      }
    """)
  end

  @doc """
  Presses Enter in the ProseMirror editor using a proper keydown event.

  This ensures the Enter key is properly handled by ProseMirror plugins.
  """
  def press_enter_in_editor(session) do
    session
    |> execute_script("""
      const pmEditor = document.querySelector('#editor-container .ProseMirror');
      if (pmEditor) {
        pmEditor.focus();
        const event = new KeyboardEvent('keydown', {
          key: 'Enter',
          code: 'Enter',
          keyCode: 13,
          which: 13,
          bubbles: true,
          cancelable: true,
          composed: true
        });
        pmEditor.dispatchEvent(event);
      }
    """)
    |> then(fn session ->
      Process.sleep(500)
      session
    end)
  end
end
