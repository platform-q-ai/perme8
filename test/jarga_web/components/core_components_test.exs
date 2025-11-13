defmodule JargaWeb.CoreComponentsTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import JargaWeb.CoreComponents

  describe "button/1" do
    test "renders a basic button with default variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button>Click me</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-primary"
      assert html =~ "Click me"
    end

    test "renders primary variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="primary">Primary</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-primary"
    end

    test "renders secondary variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="secondary">Secondary</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-secondary"
    end

    test "renders accent variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="accent">Accent</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-accent"
    end

    test "renders neutral variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="neutral">Neutral</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-neutral"
    end

    test "renders info variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="info">Info</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-info"
    end

    test "renders success variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="success">Success</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-success"
    end

    test "renders warning variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="warning">Warning</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-warning"
    end

    test "renders error variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="error">Error</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-error"
    end

    test "renders ghost variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="ghost">Ghost</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-ghost"
    end

    test "renders link variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="link">Link</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-link"
    end

    test "renders outline variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="outline">Outline</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-outline"
    end

    test "renders outline-primary variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="outline-primary">Outline Primary</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-outline"
      assert html =~ "btn-primary"
    end

    test "renders outline-error variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="outline-error">Outline Error</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-outline"
      assert html =~ "btn-error"
    end

    test "renders extra small size button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button size="xs">Extra Small</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-xs"
    end

    test "renders small size button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button size="sm">Small</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-sm"
    end

    test "renders medium size button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button size="md">Medium</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-md"
    end

    test "renders large size button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button size="lg">Large</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-lg"
    end

    test "renders button with custom classes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button class="w-full mt-4">Custom Classes</.button>
        """)

      assert html =~ "btn"
      assert html =~ "w-full"
      assert html =~ "mt-4"
    end

    test "renders button with combined variant and size" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="primary" size="lg">Large Primary</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-primary"
      assert html =~ "btn-lg"
    end

    test "renders button with phx-click attribute" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button phx-click="click_event">Click Event</.button>
        """)

      assert html =~ ~s(phx-click="click_event")
      assert html =~ "Click Event"
    end

    test "renders button with disabled attribute" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button disabled>Disabled</.button>
        """)

      assert html =~ "disabled"
      assert html =~ "Disabled"
    end

    test "renders button with name and value attributes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button name="action" value="submit">Submit Form</.button>
        """)

      assert html =~ ~s(name="action")
      assert html =~ ~s(value="submit")
    end

    test "renders link button with navigate attribute" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button navigate="/users/settings">Settings</.button>
        """)

      assert html =~ "<a"
      assert html =~ ~s(href="/users/settings")
      assert html =~ "Settings"
      refute html =~ "<button"
    end

    test "renders link button with patch attribute" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button patch="/users/edit">Edit</.button>
        """)

      assert html =~ "<a"
      assert html =~ ~s(data-phx-link="patch")
      assert html =~ ~s(href="/users/edit")
      refute html =~ "<button"
    end

    test "renders link button with href attribute" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button href="https://example.com">External Link</.button>
        """)

      assert html =~ "<a"
      assert html =~ ~s(href="https://example.com")
      refute html =~ "<button"
    end

    test "renders button element when no navigation attributes present" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button>Regular Button</.button>
        """)

      assert html =~ "<button"
      assert html =~ "Regular Button"
      refute html =~ "<a"
    end
  end

  describe "flash/1" do
    test "renders info flash message" do
      assigns = %{flash: %{"info" => "Operation successful"}}

      html =
        rendered_to_string(~H"""
        <.flash kind={:info} flash={@flash} />
        """)

      assert html =~ "Operation successful"
      assert html =~ "alert-info"
    end

    test "renders error flash message" do
      assigns = %{flash: %{"error" => "Operation failed"}}

      html =
        rendered_to_string(~H"""
        <.flash kind={:error} flash={@flash} />
        """)

      assert html =~ "Operation failed"
      assert html =~ "alert-error"
    end

    test "renders flash with title" do
      assigns = %{flash: %{"info" => "Message"}}

      html =
        rendered_to_string(~H"""
        <.flash kind={:info} flash={@flash} title="Success" />
        """)

      assert html =~ "Success"
      assert html =~ "Message"
    end

    test "renders flash with inner block content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.flash kind={:info}>Custom message from block</.flash>
        """)

      assert html =~ "Custom message from block"
    end

    test "does not render when no flash message" do
      assigns = %{flash: %{}}

      html =
        rendered_to_string(~H"""
        <.flash kind={:info} flash={@flash} />
        """)

      refute html =~ "alert"
    end

    test "renders with custom id" do
      assigns = %{flash: %{"info" => "Test"}}

      html =
        rendered_to_string(~H"""
        <.flash kind={:info} flash={@flash} id="custom-flash" />
        """)

      assert html =~ ~s(id="custom-flash")
    end
  end

  describe "icon/1" do
    test "renders heroicon" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.icon name="hero-user" />
        """)

      assert html =~ "hero-user"
    end

    test "renders lucide icon" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.icon name="lucide-settings" />
        """)

      assert html =~ "lucide-settings"
    end

    test "applies custom class to icon" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.icon name="hero-home" class="size-6 text-blue-500" />
        """)

      assert html =~ "size-6"
      assert html =~ "text-blue-500"
    end
  end

  describe "header/1" do
    test "renders header with title" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.header>
          Page Title
        </.header>
        """)

      assert html =~ "Page Title"
    end

    test "renders header with subtitle" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.header>
          Main Title
          <:subtitle>Subtitle text</:subtitle>
        </.header>
        """)

      assert html =~ "Main Title"
      assert html =~ "Subtitle text"
    end

    test "renders header with actions" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.header>
          Title
          <:actions>
            <.button>Action</.button>
          </:actions>
        </.header>
        """)

      assert html =~ "Title"
      assert html =~ "Action"
    end
  end

  describe "list/1" do
    test "renders basic list" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.list>
          <:item title="Name">John Doe</:item>
          <:item title="Email">john@example.com</:item>
        </.list>
        """)

      assert html =~ "Name"
      assert html =~ "John Doe"
      assert html =~ "Email"
      assert html =~ "john@example.com"
    end
  end

  describe "table/1" do
    test "renders table with rows" do
      assigns = %{users: [%{id: 1, name: "Alice"}, %{id: 2, name: "Bob"}]}

      html =
        rendered_to_string(~H"""
        <.table id="users" rows={@users}>
          <:col :let={user} label="ID">{user.id}</:col>
          <:col :let={user} label="Name">{user.name}</:col>
        </.table>
        """)

      assert html =~ "ID"
      assert html =~ "Name"
      assert html =~ "Alice"
      assert html =~ "Bob"
    end

    test "renders table with actions" do
      assigns = %{users: [%{id: 1, name: "Alice"}]}

      html =
        rendered_to_string(~H"""
        <.table id="users" rows={@users}>
          <:col :let={user} label="Name">{user.name}</:col>
          <:action :let={user}>
            <.button>Edit</.button>
          </:action>
        </.table>
        """)

      assert html =~ "Alice"
      assert html =~ "Edit"
    end
  end

  describe "breadcrumbs/1" do
    test "renders breadcrumbs with links" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.breadcrumbs>
          <:crumb navigate="/">Home</:crumb>
          <:crumb navigate="/users">Users</:crumb>
          <:crumb>Current Page</:crumb>
        </.breadcrumbs>
        """)

      assert html =~ "Home"
      assert html =~ "Users"
      assert html =~ "Current Page"
    end
  end

  describe "kebab_menu/1" do
    test "renders kebab menu with items" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.kebab_menu>
          <:item phx_click="edit">Edit</:item>
          <:item phx_click="delete">Delete</:item>
        </.kebab_menu>
        """)

      assert html =~ "Edit"
      assert html =~ "Delete"
    end
  end

  describe "input/1" do
    test "renders text input" do
      assigns = %{form: to_form(%{"name" => "test"})}

      html =
        rendered_to_string(~H"""
        <.input field={@form[:name]} type="text" label="Name" />
        """)

      assert html =~ "Name"
      assert html =~ ~s(type="text")
    end

    test "renders checkbox input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.input type="checkbox" name="agree" label="I agree" value="true" />
        """)

      assert html =~ "I agree"
      assert html =~ ~s(type="checkbox")
    end

    test "renders select input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.input
          type="select"
          name="role"
          label="Role"
          value=""
          options={[{"Admin", "admin"}, {"User", "user"}]}
        />
        """)

      assert html =~ "Role"
      assert html =~ "Admin"
      assert html =~ "User"
    end

    test "renders textarea input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.input type="textarea" name="description" label="Description" value="" />
        """)

      assert html =~ "Description"
      assert html =~ "<textarea"
    end

    test "renders input with errors" do
      assigns = %{form: to_form(%{"email" => ""}, errors: [email: {"can't be blank", []}])}

      html =
        rendered_to_string(~H"""
        <.input field={@form[:email]} type="email" label="Email" />
        """)

      assert html =~ "can&#39;t be blank"
    end

    test "renders input with placeholder" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.input type="text" name="search" value="" placeholder="Search..." />
        """)

      assert html =~ ~s(placeholder="Search...")
    end

    test "renders required input" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.input type="text" name="username" value="" required />
        """)

      assert html =~ "required"
    end
  end
end
