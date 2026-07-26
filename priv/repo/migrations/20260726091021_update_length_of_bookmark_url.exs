defmodule Jamie.Repo.Migrations.UpdateLengthOfBookmarkUrl do
  use Ecto.Migration

  def change do
    alter table(:bookmarks) do
      modify :url, :string, size: 2048, from: {:string, size: 255}
    end
  end
end
