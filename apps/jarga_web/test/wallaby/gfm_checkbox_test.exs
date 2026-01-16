defmodule JargaWeb.Features.GfmCheckboxTest do
  use JargaWeb.FeatureCase, async: false

  @moduletag :javascript

  describe "GFM checkbox interaction" do
    setup do
      # Use persistent test users
      user_a = Jarga.TestUsers.get_user(:alice)
      user_b = Jarga.TestUsers.get_user(:bob)

      # Create a workspace and add user_b as a member
      workspace = workspace_fixture(user_a)
      {:ok, _invitation} = Workspaces.invite_member(user_a, workspace.id, user_b.email, :member)
      {:ok, _membership} = Workspaces.accept_invitation_by_workspace(workspace.id, user_b.id)

      # Create a public document in the workspace so both users can access it
      document = document_fixture(user_a, workspace, nil, %{is_public: true})

      {:ok, user_a: user_a, user_b: user_b, workspace: workspace, document: document}
    end

    @tag :javascript
    test "user can insert a checkbox via markdown", %{
      session: session,
      user_a: user_a,
      workspace: workspace,
      document: document
    } do
      # User logs in and opens document
      session
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)
      |> click_in_editor()

      # User types checkbox markdown
      session
      |> send_keys(["- [ ] Task item"])

      # Checkbox should be rendered as li with data-item-type="task"
      session
      |> assert_has(css("li[data-item-type='task']", count: 1))

      # Checkbox should be unchecked (data-checked="false")
      session
      |> assert_has(css("li[data-item-type='task'][data-checked='false']", count: 1))

      # Task text should be visible
      content = session |> get_editor_content()
      assert content =~ "Task item"
    end

    @tag :javascript
    test "user can check a checkbox by clicking", %{
      session: session,
      user_a: user_a,
      workspace: workspace,
      document: document
    } do
      # User logs in and opens document
      session
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)
      |> click_in_editor()

      # User types checkbox markdown
      session
      |> send_keys(["- [ ] Task item"])

      # Verify checkbox is unchecked
      session
      |> assert_has(css("li[data-item-type='task'][data-checked='false']", count: 1))

      # Click the checkbox (must click on the left side, not the paragraph)
      # Wallaby's click() clicks the center, which hits the paragraph
      # So we use execute_script to click precisely on the checkbox area
      session
      |> execute_script("""
        const editor = document.querySelector('.ProseMirror');
        const taskItem = editor.querySelector('li[data-item-type="task"]');
        if (taskItem) {
          const rect = taskItem.getBoundingClientRect();
          const clickEvent = new MouseEvent('click', {
            view: window,
            bubbles: true,
            cancelable: true,
            clientX: rect.left + 15,  // Click on the checkbox (left side)
            clientY: rect.top + (rect.height / 2)
          });
          taskItem.dispatchEvent(clickEvent);
        }
      """)

      # Checkbox should now be checked
      session
      |> assert_has(css("li[data-item-type='task'][data-checked='true']", count: 1))
    end

    @tag :javascript
    test "clicking checkbox toggles state, clicking text does not", %{
      session: session,
      user_a: user_a,
      workspace: workspace,
      document: document
    } do
      # User logs in and opens document
      session
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)
      |> click_in_editor()

      # User types checkbox markdown (initially checked)
      session
      |> send_keys(["- [x] Task item"])

      # Checkbox should be checked
      session
      |> assert_has(css("li[data-item-type='task'][data-checked='true']", count: 1))

      # Click the li element on the left side (checkbox area) to toggle (should work)
      session
      |> execute_script("""
        const editor = document.querySelector('.ProseMirror');
        const taskItem = editor.querySelector('li[data-item-type="task"]');
        if (taskItem) {
          // Get the bounding rect
          const rect = taskItem.getBoundingClientRect();
          
          // Click at 15px from the left (in the checkbox area)
          const clickX = rect.left + 15;
          const clickY = rect.top + (rect.height / 2);
          
          // Create a click event with specific coordinates
          const clickEvent = new MouseEvent('click', {
            view: window,
            bubbles: true,
            cancelable: true,
            clientX: clickX,
            clientY: clickY
          });
          
          // Dispatch on the li element
          taskItem.dispatchEvent(clickEvent);
        }
      """)

      # Checkbox should now be unchecked
      session
      |> assert_has(css("li[data-item-type='task'][data-checked='false']", count: 1))

      # Now click in the middle of the text area (not on the checkbox)
      # This should NOT toggle the checkbox - this is the thorough test!
      session
      |> execute_script("""
        const editor = document.querySelector('.ProseMirror');
        const taskItem = editor.querySelector('li[data-item-type="task"]');
        if (taskItem) {
          // Get the paragraph element
          const paragraph = taskItem.querySelector('p');
          if (paragraph) {
            // Get the bounding rect of the paragraph (the text area)
            const rect = paragraph.getBoundingClientRect();
            
            // Click well into the text area (80px from task item left edge)
            // This ensures we're clicking on text, not the checkbox
            const taskRect = taskItem.getBoundingClientRect();
            const clickX = taskRect.left + 80;  // 80px from left = definitely in text
            const clickY = rect.top + (rect.height / 2);
            
            // Create a click event with specific coordinates
            // IMPORTANT: Must use bubbles: true to properly test the fix
            // The fix checks if event.target is a paragraph and blocks the toggle
            const clickEvent = new MouseEvent('click', {
              view: window,
              bubbles: true,
              cancelable: true,
              clientX: clickX,
              clientY: clickY
            });
            
            // Dispatch on the paragraph element
            paragraph.dispatchEvent(clickEvent);
          }
        }
      """)

      # BUG CHECK: Checkbox state should remain unchanged (still unchecked)
      # If this fails, it means clicking the paragraph incorrectly toggles the checkbox
      session
      |> assert_has(css("li[data-item-type='task'][data-checked='false']", count: 1))
    end

    @tag :javascript
    test "checkbox state syncs between users", %{
      session: session_a,
      user_a: user_a,
      user_b: user_b,
      workspace: workspace,
      document: document
    } do
      session_b = new_session()

      # Both users log in and open document
      session_a
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)

      session_b
      |> log_in_user(user_b)
      |> open_document(workspace.slug, document.slug)

      # Both users click to initialize
      session_a
      |> click_in_editor()

      session_b
      |> click_in_editor()

      # User A types checkbox markdown
      session_a
      |> send_keys(["- [ ] Task item"])

      # Both users should see the unchecked checkbox
      session_a
      |> assert_has(css("li[data-item-type='task'][data-checked='false']", count: 1))

      session_b
      |> assert_has(css("li[data-item-type='task'][data-checked='false']", count: 1))

      # User A checks the checkbox (click on the left side, not the paragraph)
      session_a
      |> execute_script("""
        const editor = document.querySelector('.ProseMirror');
        const taskItem = editor.querySelector('li[data-item-type="task"]');
        if (taskItem) {
          const rect = taskItem.getBoundingClientRect();
          const clickEvent = new MouseEvent('click', {
            view: window,
            bubbles: true,
            cancelable: true,
            clientX: rect.left + 15,
            clientY: rect.top + (rect.height / 2)
          });
          taskItem.dispatchEvent(clickEvent);
        }
      """)

      # Both users should see the checked checkbox
      session_a
      |> assert_has(css("li[data-item-type='task'][data-checked='true']", count: 1))

      session_b
      |> assert_has(css("li[data-item-type='task'][data-checked='true']", count: 1))

      close_session(session_b)
    end

    @tag :javascript
    test "multiple checkboxes maintain independent state", %{
      session: session,
      user_a: user_a,
      workspace: workspace,
      document: document
    } do
      # User logs in and opens document
      session
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)
      |> click_in_editor()

      # User types 3 checkboxes
      session
      |> send_keys(["- [ ] Task 1"])
      |> send_keys([:enter])
      |> send_keys(["- [ ] Task 2"])
      |> send_keys([:enter])
      |> send_keys(["- [ ] Task 3"])

      # All 3 checkboxes should be rendered and unchecked
      session
      |> assert_has(css("li[data-item-type='task']", count: 3))
      |> assert_has(css("li[data-item-type='task'][data-checked='false']", count: 3))

      # Click only the second checkbox
      # We need to get the specific checkbox by its position
      session
      |> execute_script("""
        const taskItems = document.querySelectorAll('.ProseMirror li[data-item-type="task"]');
        if (taskItems.length >= 2) {
          taskItems[1].click();
        }
      """)

      # Verify exactly 1 checkbox is checked and 2 are unchecked
      session
      |> assert_has(css("li[data-item-type='task'][data-checked='true']", count: 1))
      |> assert_has(css("li[data-item-type='task'][data-checked='false']", count: 2))
    end
  end
end
