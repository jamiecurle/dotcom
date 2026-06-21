defmodule Jamie.Storage.R2 do
  @doc """
  Returns a list of files in the :ex_aws, :s3 :bucket configuration
  """
  def list_files() do
    Application.get_env(:ex_aws, :s3)[:bucket]
    |> ExAws.S3.list_objects()
    |> ExAws.request()
    |> IO.inspect()
  end
end
