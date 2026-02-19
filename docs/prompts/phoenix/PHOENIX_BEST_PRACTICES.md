# Phoenix & LiveView Best Practices

This document consolidates best practices for developing Phoenix applications with LiveView, extracted from project guidelines and official documentation.

## Table of Contents

1. [Project Workflow](#project-workflow)
2. [Elixir Best Practices](#elixir-best-practices)
3. [Phoenix Framework](#phoenix-framework)
4. [Phoenix HTML & HEEx Templates](#phoenix-html--heex-templates)
5. [Phoenix LiveView](#phoenix-liveview)
6. [Authentication & Authorization](#authentication--authorization)
7. [Testing Strategy](#testing-strategy)
8. [UI/UX & Design](#uiux--design)

---

## Project Workflow

### Pre-commit Checks

**Always** use `mix precommit` alias when you are done with all changes and fix any pending issues before committing.

### HTTP Client Library

Use the already included `:req` (`Req`) library for HTTP requests. **Avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps.

### Mix Guidelines

- Read the docs and options before using tasks: `mix help task_name`
- To debug test failures:
  - Run tests in a specific file: `mix test test/my_test.exs`
  - Run all previously failed tests: `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

---

## Elixir Best Practices

### List Access

Elixir lists **do not support index-based access via the access syntax**.

**Never do this (invalid)**:
```elixir
i = 0
mylist = ["blue", "green"]
mylist[i]  # This will fail!
```

**Always do this**:
```elixir
i = 0
mylist = ["blue", "green"]
Enum.at(mylist, i)
```

### Variable Rebinding in Block Expressions

Elixir variables are immutable but can be rebound. For block expressions like `if`, `case`, `cond`, you **must** bind the result of the expression to a variable if you want to use it.

**Invalid**:
```elixir
# INVALID: rebinding inside the `if` - result never gets assigned
if connected?(socket) do
  socket = assign(socket, :val, val)
end
```

**Valid**:
```elixir
# VALID: rebind the result of the `if` to a variable
socket =
  if connected?(socket) do
    assign(socket, :val, val)
  end
```

### Module Organization

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors

### Struct Access

**Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly:

```elixir
# Good
my_struct.field
Ecto.Changeset.get_field(changeset, :field)

# Bad
my_struct[:field]
changeset[:field]
```

### Date and Time Handling

Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces. **Never** install additional dependencies unless asked or for date/time parsing (use the `date_time_parser` package if needed).

### Security: Atoms from User Input

**Don't** use `String.to_atom/1` on user input (memory leak risk). Use `String.to_existing_atom/1` instead if you must convert user input to atoms.

### Naming Conventions

Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards.

```elixir
# Good
def valid?(changeset), do: changeset.valid?

# Reserved for guards
defguard is_positive(number) when number > 0
```

### OTP Primitives

Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry` require names in the child spec:

```elixir
{DynamicSupervisor, name: MyApp.MyDynamicSup}
```

Then you can use:
```elixir
DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)
```

### Concurrent Enumeration

Use `Task.async_stream/3` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as an option:

```elixir
Task.async_stream(collection, callback, timeout: :infinity)
```

---

## Phoenix Framework

### Router Scope Aliases

Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

**You never need to create your own `alias` for route definitions!** The `scope` provides the alias:

```elixir
scope "/admin", AppWeb.Admin do
  pipe_through :browser

  live "/users", UserLive, :index  # Points to AppWeb.Admin.UserLive
end
```

### Phoenix.View Deprecation

`Phoenix.View` is no longer needed or included with Phoenix. Don't use it.

### Router Pipelines

Use pipelines to group common functionality and protect routes:

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {HelloWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
end

pipeline :auth do
  plug HelloWeb.Authentication
end

scope "/reviews", HelloWeb do
  pipe_through [:browser, :auth]

  resources "/", ReviewController
end
```

### Verified Routes

Use the `~p` sigil for defining route paths. The compiler checks these paths against the router, issuing warnings for any undefined routes:

```elixir
defmodule RouteExample do
  use HelloWeb, :verified_routes

  def example do
    ~p"/comments"      # Valid route
    ~p"/unknown/123"   # Compiler warning if route doesn't exist
  end
end
```

---

## Phoenix HTML & HEEx Templates

### Template Format

Phoenix templates **always** use `~H` or `.html.heex` files (known as HEEx). **Never** use `~E`.

### Forms

**Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` functions to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated.

When building forms, **always** use the already imported `Phoenix.Component.to_form/2`:

```elixir
# In LiveView
assign(socket, form: to_form(changeset))

# In template
<.form for={@form} id="msg-form">
  <.input field={@form[:field]} type="text" />
</.form>
```

### DOM IDs for Testing

**Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates. These IDs can later be used in tests:

```heex
<.form for={@form} id="product-form">
  <!-- form fields -->
</.form>
```

### App-wide Template Imports

For "app wide" template imports, import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponents, and all modules that do `use MyAppWeb, :html`.

### Conditional Logic

Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`**. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals.

**Never do this (invalid)**:
```heex
<%= if condition do %>
  ...
<% else if other_condition %>
  ...
<% end %>
```

**Always do this**:
```heex
<%= cond do %>
  <% condition -> %>
    ...
  <% condition2 -> %>
    ...
  <% true -> %>
    ...
<% end %>
```

### Literal Curly Braces

HEEx requires special tag annotation if you want to insert literal curly braces like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block, you **must** annotate the parent tag with `phx-no-curly-interpolation`:

```heex
<code phx-no-curly-interpolation>
  let obj = {key: "val"}
</code>
```

Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax.

### Class Attributes

HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes:

```heex
<a class={[
  "px-2 text-white",
  @some_flag && "py-5",
  if(@other_condition, do: "border-red-500", else: "border-blue-100")
]}>Text</a>
```

**Always** wrap `if`'s inside `{...}` expressions with parens: `if(@condition, do: "...", else: "...")`.

**Never do this** (missing `[` and `]`):
```heex
<a class={
  "px-2 text-white",
  @some_flag && "py-5"
}> ...
```

### Template Iteration

**Never** use `<% Enum.each %>` or non-for comprehensions for generating template content. **Always** use `<%= for item <- @collection do %>`:

```heex
<%= for item <- @collection do %>
  <div>{item.name}</div>
<% end %>
```

### HTML Comments

HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax:

```heex
<%!-- This is a comment --%>
```

### Interpolation

HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies.

**Always do this**:
```heex
<div id={@id}>
  {@my_assign}
  <%= if @some_block_condition do %>
    {@another_assign}
  <% end %>
</div>
```

**Never do this** (will cause syntax error):
```heex
<%!-- THIS IS INVALID --%>
<div id="<%= @invalid_interpolation %>">
  {if @invalid_block_construct do}
  {end}
</div>
```

**Rules**:
- **Always** use `{...}` syntax for interpolation within tag attributes
- **Always** use `{...}` for interpolation of values within tag bodies
- **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`

---

## Phoenix LiveView

### Phoenix v1.8 Guidelines

#### Layouts

**Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content. The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again.

#### Current Scope Errors

Anytime you run into errors with no `current_scope` assign:
- You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
- **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed

#### Flash Messages

Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module.

#### Icons and Inputs

- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar.
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available.
- If you override the default input classes with your own values, no default classes are inherited, so your custom classes must fully style the input.

### LiveView Navigation

**Never** use the deprecated `live_redirect` and `live_patch` functions. **Always** use:
- In templates: `<.link navigate={href}>` and `<.link patch={href}>`
- In LiveViews: `push_navigate` and `push_patch` functions

### LiveComponent Usage

**Avoid LiveComponents** unless you have a strong, specific need for them. Prefer function components and LiveViews for most use cases.

### LiveView Naming

LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do:

```elixir
live "/weather", WeatherLive
```

### JavaScript Hooks

**Responsibility Division:**
- **Phoenix/LiveView (Server-Side)**: Reference hooks in templates using `phx-hook` attributes
- **TypeScript (Client-Side)**: Implement the actual hook logic in `assets/js/`

When integrating LiveView with JavaScript hooks in your templates:

Remember anytime you use `phx-hook="MyHook"` and that JS hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute.

**Example (server-side template):**
```heex
<div id="my-element" phx-hook="MyHook" phx-update="ignore">
  <!-- Content managed by the JS hook -->
</div>
```

**Never** write embedded `<script>` tags in HEEx. Instead, always write your scripts and hooks in the `assets/js` directory and integrate them with the `assets/js/app.js` file.

**Note**: The actual hook implementation (in TypeScript) is handled separately. Your responsibility is to correctly reference and integrate hooks in your LiveView templates.

### Input Normalization Pattern

The interface layer must normalize weakly-typed input (query params, form data) into well-typed structures before passing to core.

**Example: LiveView Event Handler**

```elixir
# lib/my_app_web/live/app_live/workspaces/show.ex
def handle_event("create_project", %{"project" => project_params}, socket) do
  user = socket.assigns.current_scope.user
  workspace_id = socket.assigns.workspace.id

  # Delegate to core - interface doesn't validate business rules
  case Projects.create_project(user, workspace_id, project_params) do
    {:ok, _project} ->
      # Handle success

    {:error, %Ecto.Changeset{} = changeset} ->
      # Handle validation error

    {:error, _reason} ->
      # Handle authorization error
  end
end
```

**Key Points**:
- Extract and normalize parameters from socket/conn
- Call context function with well-typed arguments
- Handle different error cases appropriately
- Don't access internal context modules

### LiveView Streams

**Always** use LiveView streams for collections instead of assigning regular lists to avoid memory ballooning and runtime termination.

#### Implementing Streams in LiveComponents

**CRITICAL**: Streams in stateful LiveComponents require specific initialization:

1. **Initialize stream in `mount/1`** (called once):
```elixir
@impl true
def mount(socket) do
  {:ok, stream(socket, :notifications, [])}
end
```

2. **Populate stream in `update/2`** (called on every update):
```elixir
@impl true
def update(assigns, socket) do
  socket =
    socket
    |> assign(assigns)
    |> maybe_load_notifications()

  {:ok, socket}
end

defp load_notifications(socket) do
  notifications = Notifications.list_notifications(user_id, limit: 20)

  socket
  |> stream(:notifications, notifications, reset: true)
  |> assign(:unread_count, unread_count)
end
```

3. **Render with `phx-update="stream"`**:
```heex
<div id="notifications" phx-update="stream">
  <div id="notifications-empty-state" class="hidden only:block">
    No notifications
  </div>
  <div :for={{dom_id, notification} <- @streams.notifications} id={dom_id}>
    <.notification_item notification={notification} />
  </div>
</div>
```

**Key points**:
- Stream must be configured in `mount/1` before any items are inserted
- Once configured, a stream may not be re-configured
- Use `reset: true` when replacing entire collection
- Use `stream_insert/3` or `stream_delete/3` for individual updates

#### Basic Stream Operations

```elixir
# Configure stream (do this once in mount or update)
def mount(_params, _session, socket) do
  {:ok, stream_configure(socket, :songs, dom_id: &("songs-#{&1.id}"))}
end

# Basic append of items
stream(socket, :messages, [new_msg])

# Resetting stream with new items (e.g., for filtering items)
stream(socket, :messages, [new_msg], reset: true)

# Prepend to stream
stream(socket, :messages, [new_msg], at: -1)

# Deleting items
stream_delete(socket, :messages, msg)

# Insert or update a single item
stream_insert(socket, :songs, %Song{id: 2, title: "Song 2"})
stream_insert(socket, :songs, %Song{id: 2, title: "Song 2"}, at: 0)

# Limit stream size
stream(socket, :songs, songs, at: -1, limit: -10)
```

#### Stream Template Requirements

When using the `stream/3` interfaces in the LiveView, the LiveView template must:

1. Always set `phx-update="stream"` on the parent element
2. Set a DOM id on the parent element
3. Consume the `@streams.stream_name` collection
4. Use the id as the DOM id for each child

```heex
<div id="messages" phx-update="stream">
  <div :for={{id, msg} <- @streams.messages} id={id}>
    {msg.text}
  </div>
</div>
```

#### Stream Filtering

LiveView streams are **not enumerable**, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire collection, passing `reset: true`**:

```elixir
def handle_event("filter", %{"filter" => filter}, socket) do
  # Re-fetch the messages based on the filter
  messages = list_messages(filter)

  {:noreply,
   socket
   |> assign(:messages_empty?, messages == [])
   # Reset the stream with the new messages
   |> stream(:messages, messages, reset: true)}
end
```

#### Streams and Conditional Rendering

**⚠️ CRITICAL LIMITATION**: Streams do NOT work inside conditional rendering blocks.

**❌ WRONG - Stream inside conditional**:
```heex
<%= if @show_dropdown do %>
  <div id="notifications" phx-update="stream">
    <div :for={{id, item} <- @streams.notifications} id={id}>
      {item.text}
    </div>
  </div>
<% end %>
```

This appears to compile but **stream items will not render**. Phoenix LiveView cannot properly track stream changes when the parent element is conditionally rendered.

**✅ CORRECT - CSS-based visibility**:
```heex
<div
  id="notifications-dropdown"
  class={"#{if !@show_dropdown, do: "hidden"}"}
>
  <div id="notifications" phx-update="stream">
    <div :for={{id, item} <- @streams.notifications} id={id}>
      {item.text}
    </div>
  </div>
</div>
```

**Solution**: Use CSS to show/hide the container instead of conditional rendering:
- Keep the stream container always in the DOM
- Use `hidden` class or similar to toggle visibility
- Stream updates work correctly because the element always exists

**Why this happens**:
- Streams require a stable DOM element with `phx-update="stream"`
- Conditional rendering removes/adds the element from the DOM tree
- LiveView loses track of the stream's state when the parent is removed
- This is a known limitation of Phoenix LiveView streams (as of v1.1.16)

#### Stream Empty States

LiveView streams **do not support counting or empty states**. If you need to display a count, you must track it using a separate assign.

For empty states, use Tailwind classes with the `:only-child` selector:

```heex
<div id="tasks" phx-update="stream">
  <div class="hidden only:block">No tasks yet</div>
  <div :for={{id, task} <- @streams.tasks} id={id}>
    {task.name}
  </div>
</div>
```

The `only:` selector displays the empty state only when it's the only child of the stream container.

#### Async Streams

For asynchronous data loading, use `stream_async/3`:

```elixir
def mount(%{"slug" => slug}, _, socket) do
  current_scope = socket.assigns.current_scope

  {:ok,
   socket
   |> assign(:foo, "bar")
   |> assign_async(:org, fn -> {:ok, %{org: fetch_org!(current_scope)}} end)
   |> stream_async(:posts, fn -> {:ok, list_posts!(current_scope), limit: 10} end)}
end
```

#### Memory-Efficient Large Lists

Complete example of using streams for memory-efficient handling of large lists with pagination:

```elixir
defmodule MyAppWeb.PostsLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream(:posts, fetch_posts(), at: 0)
     |> assign(:page, 1)}
  end

  def handle_event("load_more", _params, socket) do
    page = socket.assigns.page + 1
    new_posts = fetch_posts(page: page)
    {:noreply, socket |> stream(:posts, new_posts, at: -1) |> assign(:page, page)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    delete_post(id)
    {:noreply, stream_delete(socket, :posts, %Post{id: id})}
  end

  # Handle structured domain events (Perme8 pattern)
  # In this project, all real-time updates use typed event structs:
  #   def handle_info(%PostCreated{} = event, socket) do
  #     post = load_post(event.aggregate_id)
  #     {:noreply, stream_insert(socket, :posts, post, at: 0)}
  #   end
  #
  # Generic Phoenix example (for reference):
  def handle_info({:new_post, post}, socket) do
    {:noreply, stream_insert(socket, :posts, post, at: 0)}
  end

  def render(assigns) do
    ~H"""
    <div phx-update="stream" id="posts">
      <div :for={{dom_id, post} <- @streams.posts} id={dom_id} class="post">
        <h2>{post.title}</h2>
        <p>{post.body}</p>
        <button phx-click="delete" phx-value-id={post.id}>Delete</button>
      </div>
    </div>
    <button phx-click="load_more">Load More</button>
    """
  end
end
```

**Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections.

### Form Handling

#### Creating a Form from Params

If you want to create a form based on `handle_event` params:

```elixir
def handle_event("submitted", params, socket) do
  {:noreply, assign(socket, form: to_form(params))}
end
```

You can also specify a name to nest the params:

```elixir
def handle_event("submitted", %{"user" => user_params}, socket) do
  {:noreply, assign(socket, form: to_form(user_params, as: :user))}
end
```

#### Creating a Form from Changesets

When using changesets, the underlying data, form params, and errors are retrieved from it:

```elixir
%MyApp.Users.User{}
|> Ecto.Changeset.change()
|> to_form()
```

In the template, the form assign can be passed to the `<.form>` function component:

```heex
<.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
  <.input field={@form[:field]} type="text" />
</.form>
```

Always give the form an explicit, unique DOM ID, like `id="todo-form"`.

#### Avoiding Form Errors

**Always** use a form assigned via `to_form/2` in the LiveView, and the `<.input>` component in the template.

**Always do this (valid)**:
```heex
<.form for={@form} id="my-form">
  <.input field={@form[:field]} type="text" />
</.form>
```

**Never do this (invalid)**:
```heex
<.form for={@changeset} id="my-form">
  <.input field={@changeset[:field]} type="text" />
</.form>
```

**Important rules**:
- You are **FORBIDDEN** from accessing the changeset in the template as it will cause errors
- **Never** use `<.form let={f} ...>` in the template
- **Always** use `<.form for={@form} ...>`, then drive all form references from the form assign as in `@form[:field]`
- The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset

---

## Authentication & Authorization

### Authentication Flow

**Always** handle authentication flow at the router level with proper redirects.

### Router Plugs and live_session Scopes

`phx.gen.auth` creates multiple router plugs and `live_session` scopes:

- A plug `:fetch_current_scope_for_user` that is included in the default browser pipeline
- A plug `:require_authenticated_user` that redirects to the log in page when the user is not authenticated
- A `live_session :current_user` scope - for routes that need the current user but don't require authentication
- A `live_session :require_authenticated_user` scope - for routes that require authentication
- In both cases, a `@current_scope` is assigned to the Plug connection and LiveView socket
- A plug `redirect_if_user_is_authenticated` that redirects to a default path in case the user is authenticated

### Important Authentication Guidelines

- **Always let the user know in which router scopes, `live_session`, and pipeline you are placing the route, AND SAY WHY**
- `phx.gen.auth` assigns the `current_scope` assign - it **does not assign a `current_user` assign**
- Always pass the assign `current_scope` to context modules as first argument. When performing queries, use `current_scope.user` to filter the query results
- To derive/access `current_user` in templates, **always use `@current_scope.user`**, never use `@current_user` in templates or LiveViews
- **Never** duplicate `live_session` names. A `live_session :current_user` can only be defined **once** in the router
- Anytime you hit `current_scope` errors or the logged in session isn't displaying the right content, **always double check the router and ensure you are using the correct plug and `live_session`**

### Routes that Require Authentication

LiveViews that require login should **always be placed inside the existing `live_session :require_authenticated_user` block**:

```elixir
scope "/", AppWeb do
  pipe_through [:browser, :require_authenticated_user]

  live_session :require_authenticated_user,
    on_mount: [{JargaWeb.UserAuth, :require_authenticated}] do
    # phx.gen.auth generated routes
    live "/users/settings", UserLive.Settings, :edit
    live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    # Our own routes that require logged in user
    live "/", MyLiveThatRequiresAuth, :index
  end
end
```

Controller routes must be placed in a scope that sets the `:require_authenticated_user` plug:

```elixir
scope "/", AppWeb do
  pipe_through [:browser, :require_authenticated_user]

  get "/", MyControllerThatRequiresAuth, :index
end
```

### Routes that Work With or Without Authentication

LiveViews that can work with or without authentication, **always use the existing `:current_user` scope**:

```elixir
scope "/", MyAppWeb do
  pipe_through [:browser]

  live_session :current_user,
    on_mount: [{JargaWeb.UserAuth, :mount_current_scope}] do
    # Our own routes that work with or without authentication
    live "/", PublicLive
  end
end
```

Controllers automatically have the `current_scope` available if they use the `:browser` pipeline.

### Authorization in Controllers

Use `conn.assigns.current_user` instead of directly accepting user input for authorization decisions:

```elixir
def action(conn, _) do
  args = [conn, conn.params, conn.assigns.current_user]
  apply(__MODULE__, action_name(conn), args)
end
```

### Separate Authentication Flows

Use separate `live_session`s for different authentication mechanisms:

```elixir
live_session :default do
  scope "/" do
    pipe_through [:authenticate_user]
    get ...
    live ...
  end
end

live_session :admin do
  scope "/admin" do
    pipe_through [:http_auth_admin]
    get ...
    live ...
  end
end
```

---

## Testing Strategy

### LiveView Tests

Use `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions.

#### Test Planning

Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, then gradually add interaction tests.

#### Testing Best Practices

- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element?/2`, selectors, etc
- **Never** test against raw HTML, **always** use `element/2`, `has_element?/2`, and similar functions:

```elixir
assert has_element?(view, "#my-form")
```

- Instead of relying on testing text content (which can change), favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model

#### Debugging Test Failures

When facing test failures with element selectors, add debug statements to print the actual HTML using `LazyHTML` selectors to limit the output:

```elixir
html = render(view)
document = LazyHTML.from_fragment(html)
matches = LazyHTML.filter(document, "your-complex-selector")
IO.inspect(matches, label: "Matches")
```

#### Form Testing

Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions:

```elixir
# Test form submission
form = form(view, "#my-form", post: @create_attrs)
assert render_submit(form) =~ "Post created"

# Test form validation
assert render_change(form, post: @invalid_attrs) =~ "can't be blank"
```

#### Testing File Uploads

Build file input structure for testing file uploads:

```elixir
avatar = file_input(lv, "#my-form-id", :avatar, [%{
  last_modified: 1_594_171_879_000,
  name: "myfile.jpeg",
  content: File.read!("myfile.jpg"),
  size: 1_396_009,
  type: "image/jpeg"
}])

assert render_upload(avatar, "myfile.jpeg") =~ "100%"

# Test chunk-by-chunk uploads
assert render_upload(avatar, "myfile.jpeg", 49) =~ "49%"
assert render_upload(avatar, "myfile.jpeg", 51) =~ "100%"
```

#### Testing LiveComponents

Two methods for testing LiveComponents:

**Method 1: Direct component rendering** (without events):
```elixir
assert render_component(MyComponent, id: 123, user: %User{}) =~ "some markup"
```

**Method 2: Through parent LiveView** (with events):
```elixir
{:ok, view, html} = live(conn, "/users")
html = view |> element("#user-13 a", "Delete") |> render_click()
refute html =~ "user-13"
refute view |> element("#user-13") |> has_element?()
```

#### Testing Regular Messages

Test the side effects of sending or receiving regular messages to a LiveView:

```elixir
send(view.pid, {:set_temp, 50})
assert render(view) =~ "The temperature is: 50℉"
```

**Note:** In this project, LiveView messages are structured domain event structs, not bare tuples. Use typed event structs when testing real-time updates:

```elixir
send(view.pid, %ProjectCreated{
  aggregate_id: project.id,
  actor_id: user.id,
  workspace_id: workspace.id,
  name: "New Project",
  # ... base fields (event_id, event_type, occurred_at, metadata) ...
})
assert render(view) =~ "New Project"
```

See `docs/prompts/architect/PUBSUB_TESTING_GUIDE.md` for the full event-driven testing guide.

#### Testing Portal Content

Since direct element querying inside portals is not supported, render the portal element to an HTML string:

```elixir
html = view |> element("#my-portal") |> render()
assert html =~ "something-inside"
```

#### Testing Form Actions (phx-trigger-action)

Assert and follow up on `phx-trigger-action` events:

```elixir
form = form(live_view, selector, %{"form" => "data"})
assert render_submit(form) =~ ~r/phx-trigger-action/
conn = follow_trigger_action(form, conn)
assert conn.method == "POST"
assert conn.params == %{"form" => "data"}
```

#### Isolated LiveView Testing

Spawn a connected LiveView process in isolation for testing:

```elixir
{:ok, view, html} = live_isolated(conn, MyAppWeb.ClockLive, session: %{"tz" => "EST"})

# With connect params
{:ok, view, html} =
  conn
  |> put_connect_params(%{"param" => "value"})
  |> live_isolated(AppWeb.ClockLive, session: %{"tz" => "EST"})
```

### Controller Tests

Use `ConnCase` for controller testing:

```elixir
defmodule HelloWeb.PageControllerTest do
  use HelloWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Peace of mind from prototype to production"
  end
end
```

#### Testing Create Actions

```elixir
describe "create post" do
  test "redirects to show when data is valid", %{conn: conn} do
    conn = post(conn, ~p"/posts", post: @create_attrs)

    assert %{id: id} = redirected_params(conn)
    assert redirected_to(conn) == ~p"/posts/#{id}"

    conn = get(conn, ~p"/posts/#{id}")
    assert html_response(conn, 200) =~ "Post #{id}"
  end

  test "renders errors when data is invalid", %{conn: conn} do
    conn = post(conn, ~p"/posts", post: @invalid_attrs)
    assert html_response(conn, 200) =~ "New Post"
  end
end
```

### Test Organization

Organize tests with `describe` blocks:

```elixir
defmodule HelloWeb.PostControllerTest do
  use HelloWeb.ConnCase

  import Hello.BlogFixtures

  @create_attrs %{body: "some body", title: "some title"}
  @update_attrs %{body: "some updated body", title: "some updated title"}
  @invalid_attrs %{body: nil, title: nil}

  describe "index" do
    test "lists all posts", %{conn: conn} do
      conn = get(conn, ~p"/posts")
      assert html_response(conn, 200) =~ "Listing Posts"
    end
  end

  # More describe blocks...
end
```

### Running Tests

```bash
# Run all tests
mix test

# Run tests in a specific file
mix test test/my_test.exs

# Run a specific test by line number
mix test test/my_test.exs:42

# Run previously failed tests
mix test --failed
```

---

## UI/UX & Design

### CSS and Styling

#### Tailwind CSS v4

**Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces.

Tailwind CSS v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:

```css
@import "tailwindcss" source(none);
@source "../css";
@source "../js";
@source "../../lib/my_app_web";
```

**Always use and maintain this import syntax** in the app.css file for projects generated with `phx.new`.

#### CSS Best Practices

- **Never** use `@apply` when writing raw CSS
- **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design

#### JavaScript and Asset Bundles

**Important for LiveView templates:**

Out of the box, **only the app.js and app.css bundles are supported**:
- You cannot reference an external vendored script `src` or link `href` in the layouts
- **Never write inline `<script>custom js</script>` tags within templates**

**Note**: The actual JavaScript/TypeScript code and vendor dependency management is handled by the TypeScript development workflow. As a Phoenix/LiveView developer, you only need to ensure templates don't include inline scripts.

### Design Principles

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions

---

## Summary Checklist

When working on Phoenix LiveView applications, remember to:

- ✅ Use `mix precommit` before committing
- ✅ Use verified routes with `~p` sigil
- ✅ Always use `to_form/2` for forms, never access changesets in templates
- ✅ Use LiveView streams for collections
- ✅ Add unique DOM IDs to all key elements for testing
- ✅ Use `@current_scope.user` for authentication, never `@current_user`
- ✅ Place routes in the correct `live_session` scope
- ✅ Test with element IDs, not raw HTML
- ✅ Use `<.icon>` and `<.input>` components from core_components
- ✅ Never nest modules in the same file
- ✅ Use `Enum.at/2` for list access, not bracket syntax
- ✅ Bind results of block expressions to variables
- ✅ Use `cond` for multiple conditionals, not `else if`
- ✅ Use `{...}` for attribute interpolation, `<%= ... %>` for block constructs
