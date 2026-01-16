defmodule StaticSite.Application.UseCases.ScaffoldNewSite do
  @moduledoc """
  ScaffoldNewSite use case creates a new static site with example content.

  This use case generates the complete directory structure and example files
  needed to start a new static site.
  """

  @doc """
  Creates a new static site with directory structure and example files.

  ## Options

  - `:target_path` - Where to create the site (defaults to current directory)
  - `:dir_creator` - Function for creating directories (for testing)
  - `:file_writer` - Function for writing files (for testing)

  ## Returns

  - `{:ok, %{created_dirs: list(), created_files: list()}}` on success
  - `{:error, message}` if directory already exists or creation fails

  ## Examples

      iex> ScaffoldNewSite.execute("my_blog", target_path: "/sites")
      {:ok, %{created_dirs: [...], created_files: [...]}}
  """
  @spec execute(String.t(), keyword()) ::
          {:ok, %{created_dirs: list(), created_files: list()}} | {:error, String.t()}
  def execute(site_name, opts \\ []) do
    target_path = Keyword.get(opts, :target_path, ".")
    dir_creator = Keyword.get(opts, :dir_creator, &default_dir_creator/1)
    file_writer = Keyword.get(opts, :file_writer, &default_file_writer/2)

    site_root = Path.join(target_path, site_name)

    # Check if directory already exists
    if File.exists?(site_root) do
      {:error, "Directory '#{site_name}' already exists"}
    else
      # Define directory structure
      dirs = [
        Path.join(site_root, "config"),
        Path.join(site_root, "content/posts"),
        Path.join(site_root, "content/pages"),
        Path.join(site_root, "layouts"),
        Path.join(site_root, "layouts/partials"),
        Path.join(site_root, "static/css"),
        Path.join(site_root, "static/js"),
        Path.join(site_root, "static/images")
      ]

      # Create directories
      case create_directories(dirs, dir_creator) do
        {:ok, created_dirs} ->
          # Generate and write files
          files = generate_files(site_root, site_name, opts)

          case write_files(files, file_writer) do
            {:ok, created_files} ->
              {:ok, %{created_dirs: created_dirs, created_files: created_files}}

            {:error, reason} ->
              {:error, "Failed to create files: #{inspect(reason)}"}
          end

        {:error, :eexist} ->
          {:error, "Directory '#{site_name}' already exists"}

        {:error, reason} ->
          {:error, "Failed to create directories: #{inspect(reason)}"}
      end
    end
  end

  # Private Functions

  defp create_directories(dirs, dir_creator) do
    results =
      Enum.map(dirs, fn dir ->
        case dir_creator.(dir) do
          {:ok, path} -> {:ok, path}
          {:error, reason} -> {:error, reason}
        end
      end)

    if Enum.any?(results, &match?({:error, _}, &1)) do
      {:error, elem(Enum.find(results, &match?({:error, _}, &1)), 1)}
    else
      {:ok, Enum.map(results, fn {:ok, path} -> path end)}
    end
  end

  defp write_files(files, file_writer) do
    results =
      Enum.map(files, fn {path, content} ->
        case file_writer.(path, content) do
          {:ok, path} -> {:ok, path}
          {:error, reason} -> {:error, reason}
        end
      end)

    if Enum.any?(results, &match?({:error, _}, &1)) do
      {:error, elem(Enum.find(results, &match?({:error, _}, &1)), 1)}
    else
      {:ok, Enum.map(results, fn {:ok, path} -> path end)}
    end
  end

  defp generate_files(site_root, site_name, opts) do
    # Allow tests to override the date
    date = Keyword.get(opts, :date, Date.utc_today())
    date_str = Date.to_iso8601(date)

    [
      # Configuration
      {Path.join([site_root, "config", "static_site.exs"]), generate_config(site_name)},

      # Home page
      {Path.join([site_root, "content", "index.md"]), generate_index_page(site_name)},

      # Example post
      {Path.join([site_root, "content", "posts", "#{date_str}-welcome.md"]),
       generate_welcome_post()},

      # Example page
      {Path.join([site_root, "content", "pages", "about.md"]), generate_about_page()},

      # Layouts
      {Path.join([site_root, "layouts", "default.html.heex"]), generate_default_layout()},
      {Path.join([site_root, "layouts", "home.html.heex"]), generate_home_layout()},
      {Path.join([site_root, "layouts", "post.html.heex"]), generate_post_layout()},
      {Path.join([site_root, "layouts", "page.html.heex"]), generate_page_layout()},
      {Path.join([site_root, "layouts", "collection.html.heex"]), generate_collection_layout()},
      {Path.join([site_root, "layouts", "partials", "_header.html.heex"]),
       generate_header_partial()},
      {Path.join([site_root, "layouts", "partials", "nav.html"]), generate_nav_partial()},
      {Path.join([site_root, "layouts", "partials", "footer.html"]), generate_footer_partial()},

      # Static assets
      {Path.join([site_root, "static", "css", "app.css"]), generate_css()},
      {Path.join([site_root, "static", "js", "app.js"]), generate_js()}
    ]
  end

  defp generate_config(site_name) do
    """
    import Config

    config :static_site,
      site: %{
        title: "#{String.replace(site_name, "_", " ") |> String.capitalize()}",
        url: "https://example.com",
        author: "Your Name",
        # Base path for URLs - use "" for relative links (works with file:// and web root)
        # or "/blog" for subdirectory hosting (e.g., example.com/blog/)
        base_path: "",
        theme: %{
          accent_color: "#ff5722"
        }
      },
      paths: %{
        content: "content",
        layouts: "layouts",
        static: "static",
        output: "_site"
      },
      defaults: %{
        post_layout: "post",
        page_layout: "page"
      }
    """
  end

  defp generate_index_page(site_name) do
    site_title = String.replace(site_name, "_", " ") |> String.capitalize()

    """
    ---
    title: "Welcome to #{site_title}"
    layout: home
    subtitle: "A place for thoughts, ideas, and stories"
    ---

    This is your home page. Start by exploring the site or dive into the latest posts.

    ## What You'll Find Here

    - **Thoughtful Writing**: In-depth articles and essays on various topics
    - **Fresh Perspectives**: New ideas and unique takes on interesting subjects  
    - **Regular Updates**: New content added frequently

    ## Getting Started

    Check out the [about page](pages/about.html) to learn more, or browse through the [latest posts](posts/index.html).

    ---

    *Thanks for visiting!*
    """
  end

  defp generate_welcome_post do
    datetime = DateTime.utc_now() |> DateTime.to_iso8601()

    """
    ---
    title: "Life is a beautiful journey not a destination"
    date: #{datetime}
    draft: false
    layout: post
    tags: ["lifestyle", "travel"]
    category: "Entertainment"
    intro: "Sundarbans National Park, a must-visit place in Bangladesh. Part of the Sundarbans on the Ganges Delta and home to one of the largest Bengal tiger reserves, Sundarbans National Park is one of the most naturally productive biological ecosystems on earth."
    image: "https://images.unsplash.com/photo-1608958435020-e8a7109ba809?q=80&w=2832&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=900&q=80"
    author: "Madhu"
    ---

    Bangladesh offers many tourist attractions, including archaeological sites, historical mosques and monuments, longest natural beach in the world, picturesque landscape, hill forests and wildlife, rolling tea gardens and tribes. Tourists find the rich flora and fauna and colorful tribal life very enchanting.

    Bangladesh offers many tourist attractions, including archaeological sites, historical mosques and monuments, longest natural beach in the world, picturesque landscape,

    hill forests and wildlife, rolling tea gardens and tribes. Tourists find the rich flora and fauna and colorful tribal life very enchanting.
    """
  end

  defp generate_about_page do
    """
    ---
    title: "About"
    layout: page
    subtitle: "About This Site"
    ---

    This is your about page. Tell visitors about yourself!
    """
  end

  defp generate_default_layout do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title><%= @page.title %> - <%= @site.title %></title>
      <link rel="stylesheet" href="./css/app.css">
    </head>
    <body>
      <%= render_partial("nav.html", assigns) %>
      <div class="container">
        <div class="meta">
          <div class="info">
            <div class="author">
              <div class="authorImage"></div>
              <div class="authorInfo">
                <div class="authorName">
                  <a href="index.html"><%= @site.author %></a>
                </div>
                <div class="authorSub">
                  <%= @site.title %>
                </div>
              </div>
            </div>
            <h1><%= @page.title %></h1>
            <%= if @page && is_map(@page) && Map.has_key?(@page, :frontmatter) && (@page.frontmatter["subtitle"] || Map.get(@page, :subtitle)) do %>
              <h2 class="subtitle"><%= @page.frontmatter["subtitle"] || Map.get(@page, :subtitle) %></h2>
            <% end %>
          </div>
          <div class="image"></div>
        </div>
        <div class="article">
          <%= @content %>
        </div>
      </div>
      <script src="./js/app.js"></script>
      <%= render_partial("footer.html", assigns) %>
    </body>
    </html>
    """
  end

  defp generate_home_layout do
    ~S"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title><%= @page.title %> - <%= @site.title %></title>
      <link rel="stylesheet" href="./css/app.css">
    </head>
    <body>
      <%= render_partial("nav.html", assigns) %>

      <div class="container-custom">
        <%
          # Get posts from collections.
          posts_collection = Map.get(@collections, "posts")
          posts = if posts_collection, do: posts_collection.pages, else: []

          # Sort by date descending
          sorted_posts = Enum.sort_by(posts, &(&1.date), {:desc, Date})

          # Take first 8 posts (1 Hero, 3 Sidebar, 4 Grid)
          {hero_list, rest} = Enum.split(sorted_posts, 1)
          hero = List.first(hero_list)
          {sidebar_posts, rest} = Enum.split(rest, 3)
          {grid_posts, _} = Enum.split(rest, 4)
        %>

        <%
          # Check if we have more than 1 post total
          show_sidebar = length(sorted_posts) > 1
          section_class = if show_sidebar, do: "featured-section", else: "featured-section single-post"
          hero_class = if show_sidebar, do: "hero-post", else: "hero-post hero-post-full"
        %>
        <section class="<%= section_class %>">
          <!-- Left: Hero -->
          <div class="<%= hero_class %>">
            <%= if hero do %>
              <%
                 image = hero.frontmatter["image"] || "https://images.unsplash.com/photo-1552664730-d307ca884978?auto=format&fit=crop&w=1200&q=80"
                 author = hero.frontmatter["author"] || @site.author || "Author"
                  date = if hero.date, do: Calendar.strftime(hero.date, "%B %d, %Y"), else: ""
                 url = String.trim_leading(hero.url || "", "/")
                 intro = hero.frontmatter["intro"] || hero.frontmatter["description"] || "Check out this latest post from our team."
              %>
              <div class="hero-image" style="background-image: url('<%= image %>')"></div>
              <div class="hero-content">
                <h2><a href="<%= url %>"><%= hero.title %></a></h2>
                <p><%= intro %></p>
                <div class="meta">
                  <span class="post-author"><%= author %></span>
                  <span class="date"><%= date %></span>
                </div>
              </div>
            <% else %>
              <div class="hero-content">
                <h2>No posts found.</h2>
                <p>Please add some posts to the content/posts directory.</p>
              </div>
            <% end %>
          </div>

          <%= if show_sidebar do %>
          <!-- Right: Sidebar -->
          <div class="sidebar-posts">
            <h3>Featured Posts</h3>
            <div class="divider"></div>
            <%= for post <- sidebar_posts do %>
               <%
                 author = post.frontmatter["author"] || @site.author || "Author"
                  date = if post.date, do: Calendar.strftime(post.date, "%B %d, %Y"), else: ""
                  url = String.trim_leading(post.url || "", "/")
                  intro = post.frontmatter["intro"] || post.frontmatter["description"] || ""
               %>
               <div class="sidebar-post-item">
                <h4><a href="<%= url %>"><%= post.title %></a></h4>
                <%= if intro != "" do %>
                <p class="sidebar-intro"><%= intro %></p>
                <% end %>
                <div class="meta">
                  <span class="post-author"><%= author %></span>
                  <span class="date"><%= date %></span>
                </div>
              </div>
            <% end %>
          </div>
          <% end %>
        </section>

        <!-- Bottom: Grid -->
        <section class="posts-grid">
          <%= for post <- grid_posts do %>
            <%
                 image = post.frontmatter["image"] || "https://images.unsplash.com/photo-1499750310159-5254f4197283?auto=format&fit=crop&w=600&q=80"
                 author = post.frontmatter["author"] || @site.author || "Author"
                  date = if post.date, do: Calendar.strftime(post.date, "%B %d, %Y"), else: ""
                  url = String.trim_leading(post.url || "", "/")
                  intro = post.frontmatter["intro"] || post.frontmatter["description"] || "Read more about this topic..."
             %>
             <div class="grid-post-card">
              <div class="card-image" style="background-image: url('<%= image %>')"></div>
              <div class="card-content">
                <h4><a href="<%= url %>"><%= post.title %></a></h4>
                <p><%= intro %></p>
                <div class="meta">
                  <span class="post-author"><%= author %></span>
                  <span class="date"><%= date %></span>
                </div>
              </div>
            </div>
          <% end %>
        </section>

      </div>
      <script src="./js/app.js"></script>
      <%= render_partial("footer.html", assigns) %>
    </body>
    </html>
    """
  end

  defp generate_post_layout do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title><%= @page.title %> - <%= @site.title %></title>
      <link rel="stylesheet" href="../css/app.css">
    </head>
    <body>
      <%= render_partial("nav.html", assigns) %>
      <div class="container-custom">
        
        <!-- Header Section -->
        <div class="header-grid">
            <div class="title-col">
                <h1><%= @page.title %></h1>
                <div class="category-wrapper">
                    <div class="category-line"></div>
                    <span class="category"><%= if @page.frontmatter["category"], do: @page.frontmatter["category"], else: "Post" %></span>
                </div>
            </div>
            <div class="intro-col">
                <p class="header-intro">
                    <!-- Assuming an intro/hook in frontmatter for new layout, else empty -->
                    <%= if @page.frontmatter["intro"] do %><%= @page.frontmatter["intro"] %><% end %>
                </p>
            </div>
        </div>

        <!-- Hero Image -->
        <div class="hero-image-container">
            <%= if @page.frontmatter["image"] do %>
            <img src="<%= @page.frontmatter["image"] %>" alt="<%= @page.title %>" class="hero-image">
            <% else %>
            <!-- Placeholder if no image provided -->
            <div class="hero-image" style="background-color: #f0f0f0;"></div>
            <% end %>
        </div>

        <!-- Post Details -->
        <div class="post-details">
            <h3>Post Details</h3>
            <div class="meta-info">
                <%= if @page.frontmatter["author"] do %>
                <span>Posted By <%= @page.frontmatter["author"] %>.</span>
                <% end %>
                <%= if @page.date do %><%= Calendar.strftime(@page.date, "%B %d, %Y") %><% end %>
            </div>
        </div>

        <!-- Main Content -->
        <div class="content-body">
            <%= @content %>
        </div>

      </div>
      <script src="../js/app.js"></script>
      <%= render_partial("footer.html", assigns) %>
    </body>
    </html>
    """
  end

  defp generate_page_layout do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title><%= @page.title %> - <%= @site.title %></title>
      <link rel="stylesheet" href="../css/app.css">
    </head>
    <body>
      <%= render_partial("nav.html", assigns) %>
      <div class="container-custom">

        <!-- Header Section -->
        <div class="header-grid">
            <div class="title-col">
                <h1><%= @page.title %></h1>
                <div class="category-wrapper">
                    <div class="category-line"></div>
                    <span class="category">Page</span>
                </div>
            </div>
            <div class="intro-col">
                <p class="header-intro">
                    <%= if @page.frontmatter["intro"] do %><%= @page.frontmatter["intro"] %><% end %>
                </p>
            </div>
        </div>

        <!-- Hero Image -->
        <div class="hero-image-container">
            <%= if @page.frontmatter["image"] do %>
            <img src="<%= @page.frontmatter["image"] %>" alt="<%= @page.title %>" class="hero-image">
            <% end %>
        </div>

        <!-- Post Details -->
        <div class="post-details">
            <h3><%= @page.frontmatter["subtitle"] %></h3>
        </div>

        <!-- Main Content -->
        <div class="content-body">
            <%= @content %>
        </div>

      </div>
      <script src="../js/app.js"></script>
      <%= render_partial("footer.html", assigns) %>
    </body>
    </html>
    """
  end

  defp generate_collection_layout do
    """
    <%
      # Determine the relative path prefix for collection pages
      # Collections are typically at root level (categories, tags) so they need ".."
      # to reach assets that are also at root
      url = cond do
        is_nil(assigns) -> ""
        is_map(assigns) && is_map_key(assigns, :page) ->
          page = assigns[:page]
          cond do
            is_nil(page) -> ""
            is_struct(page) && is_map_key(page, :url) -> page.url
            is_map(page) -> Map.get(page, :url, "")
            true -> ""
          end
        true -> ""
      end
      
      url_parts = String.split(url || "", "/", trim: true)
      # Collections are typically at /categories/X.html or /tags/X.html
      # If URL has directory parts, use ".." to go up to root
      base = if length(url_parts) > 1, do: "..", else: "."
    %>
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title><%= @page.title %> - <%= @site.title %></title>
      <link rel="stylesheet" href="<%= base %>/css/app.css">
    </head>
    <body>
      <%= render_partial("nav.html", assigns) %>
      <div class="container-custom">

        <!-- Header Section -->
        <div class="header-grid">
            <div class="title-col">
                <h1><%= @page.title %></h1>
                <div class="category-wrapper">
                    <div class="category-line"></div>
                    <span class="category">Collection</span>
                </div>
            </div>
            <div class="intro-col">
                <p class="header-intro">
                    <%= if @page && is_map(@page) && Map.has_key?(@page, :frontmatter) && @page.frontmatter["description"] do %><%= @page.frontmatter["description"] %><% end %>
                </p>
            </div>
        </div>

        <!-- Hero Image -->
        <div class="hero-image-container">
        </div>

        <!-- Main Content -->
        <div class="content-body">
            <%= @content %>
        </div>

      </div>
      <script src="<%= base %>/js/app.js"></script>
      <%= render_partial("footer.html", assigns) %>
    </body>
    </html>
    """
  end

  defp generate_header_partial do
    """
    <div class="author">
      <div class="authorImage"></div>
      <div class="authorInfo">
        <div class="authorName">
          <a href="/"><%= @site.author %></a>
        </div>
      </div>
    </div>
    """
  end

  defp generate_footer_partial do
    """
    <%
      # Determine the relative path prefix based on page depth
      url = cond do
        is_nil(assigns) -> ""
        is_map(assigns) && is_map_key(assigns, :page) ->
          page = assigns[:page]
          cond do
            is_nil(page) -> ""
            is_struct(page) && is_map_key(page, :url) -> page.url
            is_map(page) -> Map.get(page, :url, "")
            true -> ""
          end
        true -> ""
      end

      url_parts = String.split(url || "", "/", trim: true)
      base = if length(url_parts) > 1, do: "..", else: "."

      # Get current year
      current_year = Date.utc_today().year
    %>
    <footer class="site-footer">
      <div class="footer-container">
        <p class="copyright">&copy; <%= current_year %> <%= @site.title %>. All rights reserved.</p>
      </div>
    </footer>
    """
  end

  defp generate_nav_partial do
    """
    <%
      # Determine the relative path prefix based on page depth
      # Root pages (index.html): use "."
      # Nested pages (posts/*, pages/*): use ".."
      # Safely extract URL from assigns with multiple fallbacks
      url = cond do
        is_nil(assigns) -> ""
        is_map(assigns) && is_map_key(assigns, :page) ->
          page = assigns[:page]
          cond do
            is_nil(page) -> ""
            is_struct(page) && is_map_key(page, :url) -> page.url
            is_map(page) -> Map.get(page, :url, "")
            true -> ""
          end
        true -> ""
      end
      
      url_parts = String.split(url || "", "/", trim: true)
      # If URL has parts (e.g., "posts/my-post"), we're nested - use ".."
      # If URL is empty or just a filename (e.g., "index.html"), we're at root - use "."
      base = if length(url_parts) > 1, do: "..", else: "."
    %>
    <nav class="site-nav">
      <div class="nav-container">
        <div class="site-logo">
          <a href="<%= base %>/index.html"><%= @site.title %></a>
        </div>
        <ul>
          <li><a href="<%= base %>/index.html">Home</a></li>
          <li><a href="<%= base %>/posts/index.html">Posts</a></li>
          <li><a href="<%= base %>/pages/about.html">About</a></li>
        </ul>
      </div>
    </nav>
    """
  end

  defp generate_css do
    """
    @import url('https://fonts.googleapis.com/css?family=Lato:400,700|Lora|Playfair+Display:700i,900');

    html,
    body {
      margin: 0;
      width: 100%;
      --accent-color: #ff5722;
      --accent-color-light: color-mix(in srgb, var(--accent-color) 30%, transparent);
    }

    h1,
    h2,
    p,
    i,
    a,
    .first-letter,
    .authorName a {
      color: rgba(0, 0, 0, 0.84);
      text-rendering: optimizeLegibility;
    }

    h1 {
      font-family: "Playfair Display", serif;
      font-size: 48px;
      text-align: left;
      margin-bottom: 8px;
    }

    h2 {
      font-family: "Lato", sans-serif;
      font-size: 26px;
      font-weight: 700;
      padding: 0;
      margin: 56px 0 -13px -1.883px;
      text-align: left;
      line-height: 34.5px;
      letter-spacing: -0.45px;
    }

    p, i, a {
      margin-top: 21px;
      font-family: "Lora";
      font-size: 21px;
      letter-spacing: -0.03px;
      line-height: 1.58;
    }

    a {
      text-decoration: underline;
    }

    blockquote {
      font-family: "Playfair Display", serif;
      font-size: 30px;
      font-style: italic;
      letter-spacing: -0.36px;
      line-height: 44.4px;
      overflow-wrap: break-word;
      margin: 55px 0 33px 0;
      /* text-align: center; */
      color: rgba(0, 0, 0, 0.68);
      padding: 0 0 0 50px;
    }

    hr {
      border: 0;
      border-top: 1px solid var(--accent-color-light);
      margin: 2rem 0;
    }

    ul, ol {
      font-family: "Lora";
      font-size: 21px;
      letter-spacing: -0.03px;
      line-height: 1.58;
      margin: 21px 0;
      padding-left: 30px;
      color: rgba(0, 0, 0, 0.84);
    }

    ul {
      list-style-type: disc;
    }

    ol {
      list-style-type: decimal;
    }

    li {
      margin-bottom: 14px;
      padding-left: 8px;
    }

    li:last-child {
      margin-bottom: 0;
    }

    /* Nested lists */
    ul ul, ol ul {
      list-style-type: circle;
      margin-top: 10px;
      margin-bottom: 10px;
    }

    ul ol, ol ol {
      list-style-type: lower-alpha;
      margin-top: 10px;
      margin-bottom: 10px;
    }

    /* Lists inside blockquotes */
    blockquote ul, blockquote ol {
      font-family: "Playfair Display", serif;
      font-size: 30px;
      font-style: italic;
    }

    code {
      font-size: 18px;
      background: rgba(0,0,0,.05);
      border-radius: 2px;
      padding: 3px 5px;
    }

    .highlighted {
      background: #7DFFB3;
    }

    .subtitle {
      font-family: "Lato", sans-serif;
      color: rgba(0, 0, 0, 0.54);
      margin: 0 0 24px 0;
    }

    /* Navigation */
    .site-nav {
      background-color: rgba(255, 255, 255, 0.98);
      border-bottom: 1px solid var(--accent-color-light);
      padding: 1rem 0;
      position: sticky;
      top: 0;
      z-index: 1000;
      backdrop-filter: blur(8px);
    }

    .nav-container {
      max-width: 1200px;
      margin: 0 auto;
      padding: 0 1.5rem;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .site-logo a {
      font-family: "Playfair Display", serif;
      font-weight: 900;
      font-size: 24px;
      text-decoration: none;
      color: #000;
      margin-top: 0;
    }

    .site-nav ul {
      list-style: none;
      display: flex;
      gap: 2rem;
      margin: 0;
      padding: 0;
    }

    .site-nav li {
      margin: 0;
    }

    .site-nav ul a {
      font-family: "Lato", sans-serif;
      color: rgba(0, 0, 0, 0.68);
      font-size: 16px;
      font-weight: 400;
      text-decoration: none;
      padding: 0.5rem 0;
      display: inline-block;
      transition: color 0.2s ease;
      margin-top: 0;
      letter-spacing: 0;
    }

    .site-nav ul a:hover {
      color: rgba(0, 0, 0, 0.88);
    }

    @media (max-width: 600px) {
      .nav-container {
        flex-direction: column;
        gap: 1rem;
      }
    }

    /* Footer */
    .site-footer {
      background-color: rgba(255, 255, 255, 0.98);
      border-top: 1px solid var(--accent-color-light);
      padding: 2rem 0;
      margin-top: 60px;
    }

    .footer-container {
      max-width: 1200px;
      margin: 0 auto;
      padding: 0 1.5rem;
      text-align: center;
    }

    .copyright {
      font-family: "Lato", sans-serif;
      font-size: 14px;
      color: rgba(0, 0, 0, 0.54);
      margin: 0;
    }

    /* Collection Pages - Posts List */
    .collection-meta {
      font-family: "Lato", sans-serif;
      font-size: 16px;
      color: rgba(0, 0, 0, 0.54);
      margin: 0 0 32px 0;
      font-weight: 400;
    }

    .posts {
      margin: 0;
      padding: 0;
    }

    .post-item {
      border-bottom: 1px solid var(--accent-color-light);
      padding: 28px 0;
      margin: 0;
    }

    .post-item:first-child {
      padding-top: 0;
    }

    .post-item:last-child {
      border-bottom: none;
    }

    .post-title {
      font-family: "Lato", sans-serif;
      font-size: 28px;
      font-weight: 700;
      margin: 0 0 8px 0;
      line-height: 1.3;
      letter-spacing: -0.45px;
    }

    .post-title a {
      color: rgba(0, 0, 0, 0.84);
      text-decoration: none;
      transition: color 0.2s ease;
      margin-top: 0;
    }

    .post-title a:hover {
      color: rgba(0, 0, 0, 0.68);
    }

    .post-date {
      font-family: "Lato", sans-serif;
      font-size: 14px;
      color: rgba(0, 0, 0, 0.54);
      font-weight: 400;
      display: block;
      margin-top: 4px;
    }

    .post-intro {
      font-family: "Lato", sans-serif;
      font-size: 16px;
      color: rgba(0, 0, 0, 0.6);
      margin: 4px 0 8px 0;
      line-height: 1.5;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }

    /* ##################################################################################
    ########################################  LAYOUT  ###################################
    ##################################################################################### */

    .container {
      display: -ms-grid;
      display: grid;
          -ms-grid-columns: auto 166px 740px 166px auto;
          grid-template-columns: auto 166px 740px 166px auto;
          -ms-grid-rows: 450px auto;
          grid-template-rows: 450px auto;
          grid-template-areas:
        ". img img img ."
        ". . article . .";
    }

    .meta {
      -ms-grid-row: 1;
      -ms-grid-column: 2;
      -ms-grid-column-span: 3;
      grid-area: img;
      margin: 10px;

      display: -ms-grid;

      display: grid;
          -ms-grid-rows: auto;
          grid-template-rows: auto;
          -ms-grid-columns: 1fr 1fr;
          grid-template-columns: 1fr 1fr;
          grid-template-areas:
        "info image";
    }

    .image {
      -ms-grid-row: 1;
      -ms-grid-column: 2;
      grid-area: image;
      background: url("https://images.unsplash.com/photo-1525547719571-a2d4ac8945e2?ixlib=rb-0.3.5&ixid=eyJhcHBfaWQiOjEyMDd9&s=ec073341402b36bb155e3bcb77eea9cd&dpr=1&auto=format&fit=crop&w=1000&q=80&cs=tinysrgb");
      background-size: cover;
      background-repeat: no-repeat;
    }

    .info {
      -ms-grid-row: 1;
      -ms-grid-column: 1;
      grid-area: info;
      padding: 60px 60px 0 0;
      margin-bottom: 30px;
    }

    .author {
      display: -ms-grid;
      display: grid;
          -ms-grid-columns: 60px auto;
          grid-template-columns: 60px auto;
          -ms-grid-rows: 60px;
          grid-template-rows: 60px;
          grid-template-areas:
        "authorImage authorInfo";
    }

    .authorImage {
      -ms-grid-row: 1;
      -ms-grid-column: 1;
      grid-area: authorImage;
      border: 2px solid #7DFFB3;
      border-radius: 50%;
      background: url('https://s3-us-west-2.amazonaws.com/s.cdpn.io/1307985/profile/profile-512.jpg?1520076483');
      background-size: cover;
    }

    .authorInfo {
      -ms-grid-row: 1;
      -ms-grid-column: 2;
      grid-area: authorInfo;
      padding-left: 10px;
    }

    .authorName,
    .authorSub {
      font-family: "Lato", sans-serif;
      font-size: 16px;
      font-weight: 400;
      margin-top: 6px;
    }

    .authorName a {
      font-size: inherit;
      font-family: inherit;
      text-decoration: none;
    }

    .authorName a:hover {
      text-decoration: underline;
    }

    .authorSub {
      color: rgba(0, 0, 0, 0.54);
    }

    .median-divider {
      padding: 0 6px;
    }

    .lineLength {
      border: 2px dashed rgba(0, 0, 0, 0.54);
    }

    .article {
      -ms-grid-row: 2;
      -ms-grid-column: 3;
      grid-area: article;
      margin: 40px 10px;
    }

    @media screen and (max-width: 1072px) {
      .container {
            -ms-grid-columns: auto 740px auto;
            grid-template-columns: auto 740px auto;
            -ms-grid-rows: auto auto;
            grid-template-rows: auto auto;
            grid-template-areas:
          ". img ."
          ". article .";
      }
      .meta {
        -ms-grid-row: 1;
        -ms-grid-column: 2;
        -ms-grid-column-span: 1;
      }
      .article {
        -ms-grid-row: 2;
        -ms-grid-column: 2;
      }
    }

    @media screen and (max-width: 740px) {
      .container {
            -ms-grid-rows: auto auto;
            grid-template-rows: auto auto;
            -ms-grid-columns: auto;
            grid-template-columns: auto;
            grid-template-areas:
          "img"
          "article";
      }

      .meta {
            -ms-grid-rows: 1fr 1fr;
            grid-template-rows: 1fr 1fr;
            -ms-grid-columns: 1fr;
            grid-template-columns: 1fr;
            grid-template-areas:
          "info"
          "image";
      }
      .info {
        padding-top: 0;
      }
      .meta {
        -ms-grid-row: 1;
        -ms-grid-column: 1;
        -ms-grid-column-span: 1;
      }

      .image {
        -ms-grid-row: 2;
        -ms-grid-column: 1;
      }

      .info {
        -ms-grid-row: 1;
        -ms-grid-column: 1;
      }
      .article {
        -ms-grid-row: 2;
        -ms-grid-column: 1;
      }
    }

    /* ##################################################################################
    ########################################  POST STYLES (NEW)  ###################################
    ##################################################################################### */

    .container-custom {
        max-width: 1100px;
        margin: 0 auto;
        padding: 60px 20px;
        min-height: calc(100vh - 200px);
    }

    .header-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 60px;
        margin-bottom: 50px;
        align-items: start;
    }

    .header-grid h1 {
        font-family: "Playfair Display", serif;
        font-size: 52px;
        line-height: 1.1;
        font-weight: 900;
        margin-top: 0;
        margin-bottom: 25px;
        color: #000;
    }

    .category-wrapper {
        display: flex;
        align-items: center;
        gap: 15px;
    }

    .category-line {
        height: 2px;
        width: 50px;
        background-color: var(--accent-color);
    }

    .category {
        font-family: "Lato", sans-serif;
        font-size: 16px;
        color: #333;
    }

    .header-intro {
        font-family: "Lato", sans-serif;
        font-size: 18px;
        line-height: 1.6;
        color: rgba(0,0,0,0.75);
        margin-top: 10px;
    }

    .hero-image-container {
        width: 100%;
        margin-bottom: 50px;
    }

    .hero-image {
        width: 100%;
        height: 400px; /* Fixed height to match design banner style */
        object-fit: cover; /* Ensures image covers area without distortion */
        display: block;
    }

    .post-details {
        margin-bottom: 40px;
        border-bottom: 1px solid var(--accent-color-light);
        padding-bottom: 40px;
    }

    .post-details h3 {
        font-family: "Lato", sans-serif;
        font-size: 28px;
        font-weight: 700;
        margin: 0 0 15px 0;
        color: #000;
    }

    .meta-info {
        display: flex;
        align-items: center;
        gap: 8px;
        font-family: "Lato", sans-serif;
        font-size: 14px;
        color: #666;
    }

    .avatar {
        width: 24px;
        height: 24px;
        border-radius: 50%;
        object-fit: cover;
        margin-left: 5px;
        margin-right: 5px;
    }

    .content-body p {
        font-family: "Lato", sans-serif;
        font-size: 18px;
        line-height: 1.7;
        color: #333;
        margin-bottom: 25px;
        max-width: 100%;
    }

    @media (max-width: 768px) {
        .header-grid {
            grid-template-columns: 1fr;
            gap: 30px;
        }
        .header-grid h1 { font-size: 40px; }
    }

    /* ##################################################################################
    ########################################  HOME LAYOUT  ################################
    ##################################################################################### */

    /* Home Layout Styles */
    .featured-section {
      display: grid;
      grid-template-columns: 2fr 1fr;
      gap: 60px;
      margin-bottom: 60px;
    }

    /* Single post layout - hero takes full width */
    .featured-section.single-post {
      grid-template-columns: 1fr;
    }

    .hero-post-full {
      grid-column: 1 / -1;
    }

    /* Hero */
    .hero-post .hero-image {
      width: 100%;
      height: 450px;
      background-size: cover;
      background-position: center;
      margin-bottom: 24px;
      background-color: #f0f0f0;
      border-radius: 4px;
    }

    .hero-post h2 {
      font-family: "Playfair Display", serif;
      font-size: 42px;
      font-weight: 700;
      margin: 0 0 16px 0;
      line-height: 1.2;
    }
    .hero-post h2 a {
      text-decoration: none;
      color: #111;
      transition: color 0.2s;
    }
    .hero-post h2 a:hover {
      color: #555;
    }

    .hero-post p {
      font-family: "Lora", serif;
      font-size: 20px;
      color: #333;
      margin-bottom: 24px;
      line-height: 1.6;
    }

    .hero-post .meta {
      font-family: "Lato", sans-serif;
      font-size: 15px;
      color: #666;
      display: flex;
      flex-direction: column;
      gap: 0;
      margin: 0;
    }

    .hero-post .meta .post-author {
      font-weight: 700;
      color: #333;
    }

    .hero-post .meta .date {
      margin-top: 4px;
    }

    /* Sidebar */
    .sidebar-posts h3 {
      font-family: "Lato", sans-serif;
      font-size: 20px;
      font-weight: 700;
      margin-bottom: 12px;
      margin-top: 0;
      color: #111;
    }

    .sidebar-posts .divider {
      height: 2px;
      background-color: var(--accent-color);
      width: 100%;
      margin-bottom: 24px;
    }

    .sidebar-post-item {
      margin-bottom: 24px;
      border-bottom: 1px solid var(--accent-color-light);
      padding-bottom: 24px;
    }
    .sidebar-post-item:last-child {
      border-bottom: none;
    }

    .sidebar-post-item h4 {
      font-family: "Lato", sans-serif;
      font-size: 18px;
      font-weight: 700;
      margin: 0 0 8px 0;
      line-height: 1.4;
    }
    .sidebar-post-item h4 a {
      text-decoration: none;
      color: #111;
      transition: color 0.2s;
    }
    .sidebar-post-item h4 a:hover {
      color: #555;
    }

    .sidebar-post-item .meta {
      display: flex;
      flex-direction: column;
      gap: 0;
      margin: 0;
      margin-top: 1rem;
      font-family: "Lato", sans-serif;
      font-size: 14px;
      color: #777;
    }

    .sidebar-post-item .meta .post-author {
      font-weight: 700;
      color: #333;
    }

    .sidebar-post-item .meta .date {
      margin-top: 4px;
    }

    .sidebar-intro {
      font-family: "Lato", sans-serif;
      font-size: 15px;
      color: #444;
      margin-top: 4px;
      margin-bottom: 8px;
      line-height: 1.4;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }

    /* Grid */
    .posts-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 30px;
      margin-top: 40px;
    }

    .grid-post-card {
      display: flex;
      flex-direction: column;
      height: 100%;
    }

    .grid-post-card .card-content {
      display: flex;
      flex-direction: column;
      flex-grow: 1;
    }

    .grid-post-card .card-image {
      width: 100%;
      height: 200px;
      background-size: cover;
      background-position: center;
      margin-bottom: 16px;
      background-color: #f0f0f0;
      border-radius: 4px;
    }

    .grid-post-card h4 {
      font-family: "Lato", sans-serif;
      font-size: 18px;
      font-weight: 700;
      margin: 0 0 12px 0;
      line-height: 1.4;
      min-height: 80px; /* Aligns the intro text (approx 3 lines) */
      display: -webkit-box;
      -webkit-line-clamp: 3;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }
    .grid-post-card h4 a {
      text-decoration: none;
      color: #111;
    }

    .grid-post-card p {
      font-family: "Lato", sans-serif;
      font-size: 15px;
      color: #444;
      margin-bottom: 16px;
      line-height: 1.5;
      display: -webkit-box;
      -webkit-line-clamp: 3;
      -webkit-box-orient: vertical;
      overflow: hidden;
      flex-grow: 1; /* Pushes meta to bottom */
    }

    .grid-post-card .meta {
      font-family: "Lato", sans-serif;
      font-size: 13px;
      color: #777;
      display: flex;
      flex-direction: column;
      gap: 0;
      margin: 0;
    }

    .grid-post-card .meta .post-author {
      font-weight: 700;
      color: #333;
    }

    .grid-post-card .meta .date {
      margin-top: 4px;
    }

    @media (max-width: 1024px) {
      .posts-grid {
        grid-template-columns: repeat(2, 1fr);
      }
    }

    @media (max-width: 768px) {
      .featured-section {
        grid-template-columns: 1fr;
      }
      .hero-post .hero-image {
        height: 300px;
      }
      .sidebar-posts {
        margin-top: 40px;
      }
    }

    @media (max-width: 480px) {
      .posts-grid {
        grid-template-columns: 1fr;
      }
      .hero-post h2 {
        font-size: 32px;
      }
    }
    """
  end

  defp generate_js do
    "// Your JavaScript here\n"
  end

  # Default implementations

  defp default_dir_creator(path) do
    case File.mkdir_p(path) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  defp default_file_writer(path, content) do
    case File.write(path, content) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end
end
