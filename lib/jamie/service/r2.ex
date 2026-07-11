defmodule Jamie.Service.R2 do
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
  def put_file(contents, filename) do
    Application.get_env(:ex_aws, :s3)[:bucket]
    |> ExAws.S3.put_object(filename, contents, content_type: content_type(filename))
    |> ExAws.request()
  end

  defp content_type(filename) do
    case Path.extname(filename) do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".svg" -> "image/svg+xml"
      ".pdf" -> "application/pdf"
      _ -> "application/octet-stream"
    end
  end
end
