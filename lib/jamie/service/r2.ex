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

  @doc """
  Lists every object under `prefix` as `{key, size_in_bytes}` pairs.

  Streams so that buckets with more than a page of objects come back whole.
  """
  def list_objects(prefix \\ "") do
    Application.get_env(:ex_aws, :s3)[:bucket]
    |> ExAws.S3.list_objects_v2(prefix: prefix)
    |> ExAws.stream!()
    |> Enum.map(fn object -> {object.key, String.to_integer(object.size)} end)
  end

  @doc """
  Lists every object under `prefix` as `{key, last_modified}` pairs, where
  `last_modified` is a `DateTime` - when the object was uploaded.
  """
  def list_objects_modified(prefix) do
    Application.get_env(:ex_aws, :s3)[:bucket]
    |> ExAws.S3.list_objects_v2(prefix: prefix)
    |> ExAws.stream!()
    |> Enum.map(fn object ->
      # R2 hands back ISO 8601, e.g. "2026-10-10T09:15:00.000Z"
      {:ok, modified, _offset} = DateTime.from_iso8601(object.last_modified)
      {object.key, modified}
    end)
  end

  @doc """
  Copies an object to a new key within the same bucket.

  This is a server-side copy - the bytes never leave R2.
  """
  def copy_file(source_key, destination_key) do
    bucket = Application.get_env(:ex_aws, :s3)[:bucket]

    bucket
    |> ExAws.S3.put_object_copy(destination_key, bucket, source_key)
    |> ExAws.request()
  end

  @doc """
  Deletes objects in one request. S3 caps a single call at 1000 keys.
  """
  def delete_files(keys) do
    Application.get_env(:ex_aws, :s3)[:bucket]
    |> ExAws.S3.delete_multiple_objects(keys)
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
