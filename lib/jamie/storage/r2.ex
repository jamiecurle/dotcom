defmodule Jamie.Storage.R2 do
  @moduledoc """
  A basic storage backend context for R2
  """

  @doc """
  Returns a list of files in the :ex_aws, :s3 :bucket configuration
  """
  def list_files do
    Application.get_env(:ex_aws, :s3)[:bucket]
    |> ExAws.S3.list_objects()
    |> ExAws.request()
  end

  @doc """
  Returns a list of files in the :ex_aws, :s3 :bucket configuration
  """
  def get_file(key) do
    Application.get_env(:ex_aws, :s3)[:bucket]
    |> ExAws.S3.get_object(key)
    |> ExAws.request()
  end

  @doc """
  Returns a list of files in the :ex_aws, :s3 :bucket configuration
  """
  def put_file(_key) do
    # TODO
  end
end
