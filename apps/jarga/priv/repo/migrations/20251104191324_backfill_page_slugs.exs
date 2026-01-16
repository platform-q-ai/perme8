defmodule Jarga.Repo.Migrations.BackfillPageSlugs do
  use Ecto.Migration

  import Ecto.Query

  def up do
    # Get all pages without slugs
    pages_query = from p in "pages",
      where: is_nil(p.slug),
      select: %{id: p.id, title: p.title, workspace_id: p.workspace_id}

    pages = repo().all(pages_query)

    # Generate slugs for each page
    Enum.each(pages, fn page ->
      slug = generate_slug(page.title, page.workspace_id)

      from(p in "pages", where: p.id == ^page.id)
      |> repo().update_all(set: [slug: slug])
    end)
  end

  def down do
    # No need to remove slugs on rollback
    :ok
  end

  defp generate_slug(title, workspace_id) do
    base_slug = title
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\s-]/, "")
      |> String.replace(~r/\s+/, "-")
      |> String.trim_trailing("-")

    ensure_unique_slug(base_slug, workspace_id)
  end

  defp ensure_unique_slug(base_slug, workspace_id, attempt \\ 0) do
    slug = if attempt == 0 do
      base_slug
    else
      "#{base_slug}-#{generate_random_suffix()}"
    end

    # Check if slug exists in workspace
    query = from p in "pages",
      where: p.workspace_id == ^workspace_id and p.slug == ^slug,
      select: count()

    case repo().one(query) do
      0 -> slug
      _ -> ensure_unique_slug(base_slug, workspace_id, attempt + 1)
    end
  end

  defp generate_random_suffix do
    :crypto.strong_rand_bytes(4)
    |> Base.encode16(case: :lower)
    |> String.slice(0, 6)
  end
end
