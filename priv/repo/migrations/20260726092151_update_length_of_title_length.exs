defmodule Jamie.Repo.Migrations.UpdateWebsiteTitleAndTitleLength do
  use Ecto.Migration

  def change do
    alter table(:bookmarks) do
      modify :title, :string, size: 512, from: {:string, size: 255}
    end
  end
end
