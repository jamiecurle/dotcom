defmodule Jamie.Blog.Test do
  use Jamie.DataCase, async: true

  alias Jamie.Accounts.Scope
  alias Jamie.AccountsFixtures
  alias Jamie.Blog
  alias Jamie.Blog.Post
  alias Jamie.Repo
  alias Jamie.Support.BlogFixtures

  describe "get_post_by_slug!" do
    test "if scope has no user then only published posts work" do
      # make a scope for a nil user
      scope = Scope.for_user(nil)

      # make a post
      {:ok, post} =
        BlogFixtures.blog_attrs(title: "now now, there's no need for that", status: :draft)
        |> Blog.create_post()

      # it's draft so it raises as there's no scope
      assert_raise Ecto.NoResultsError, fn ->
        Blog.get_post_by_slug!(post.slug, scope).id
      end

      # as does hidden
      Blog.update_post(post, %{status: :hidden})

      assert_raise Ecto.NoResultsError, fn ->
        Blog.get_post_by_slug!(post.slug, scope).idh
      end

      # but published is fine
      Blog.update_post(post, %{status: :published})
      assert post.id == Blog.get_post_by_slug!(post.slug).id
    end

    test "if scope has a user they can access any post by slug" do
      user = AccountsFixtures.user_fixture()
      scope = Scope.for_user(user)

      # make a post
      {:ok, post} =
        BlogFixtures.blog_attrs(title: "now now, there's no need for that", status: :draft)
        |> Blog.create_post()

      assert post.id == Blog.get_post_by_slug!(post.slug, scope).id

      # published works too
      Blog.update_post(post, %{status: :published})
      assert post.id == Blog.get_post_by_slug!(post.slug, scope).id

      # as does hidden
      Blog.update_post(post, %{status: :hidden})
      assert post.id == Blog.get_post_by_slug!(post.slug, scope).id
    end

    test "but doesn't have to accept a scope" do
      {:ok, post} =
        BlogFixtures.blog_attrs(title: "now now, there's no need for that", status: :published)
        |> Blog.create_post()

      assert post.id == Blog.get_post_by_slug!(post.slug).id
    end

    test "no scope means the post has to be published" do
      # make a post
      {:ok, post} =
        BlogFixtures.blog_attrs(title: "now now, there's no need for that", status: :draft)
        |> Blog.create_post()

      # it's draft so it raises as there's no scope
      assert_raise Ecto.NoResultsError, fn ->
        Blog.get_post_by_slug!(post.slug).id
      end

      # but update the post and it can be got
      Blog.update_post(post, %{status: :published})
      assert post.id == Blog.get_post_by_slug!(post.slug).id
    end
  end

  describe "publishing_posts for the first time gives them a published date" do
    test "when a post is published, the published date is is filled in" do
      # new post, draft status
      {:ok, post} =
        BlogFixtures.blog_attrs(title: "now now, there's no need for that", status: :draft)
        |> Blog.create_post()

      # there is no published on
      refute post.published_on

      # now save as published and there's a published date
      {:ok, post} = Blog.update_post(post, %{status: :published})
      assert post.published_on
    end
  end

  describe "published_posts/0" do
    test "only published posts are returned" do
      {:ok, post1} =
        BlogFixtures.blog_attrs(status: :published)
        |> Blog.create_post()

      {:ok, post2} =
        BlogFixtures.blog_attrs(title: "now now, there's no need for that", status: :draft)
        |> Blog.create_post()

      # we have two posts
      assert 2 == Repo.aggregate(Post, :count)
      assert post1.status == :published
      assert post2.status == :draft

      # published_posts/0 returns 1 post
      assert 1 == Blog.published_posts() |> length()

      # update post2 to published and we now have two
      Blog.change_post(post2, %{status: :published}) |> Repo.update()
      assert 2 == Blog.published_posts() |> length()
    end
  end

  describe "update_post/1" do
    test "iframe is allowed when updating a post" do
      # make a post
      {:ok, post} =
        BlogFixtures.blog_attrs()
        |> Blog.create_post()

      refute post.html =~ "<iframe"

      # now update the post to have an iframe
      attrs = %{markdown: "<iframe src=https://foo.com></iframe>"}
      {:ok, post} = Blog.update_post(post, attrs)

      assert post.html =~ "<iframe"
    end
  end

  describe "change_post/1" do
    test "returns an empty changeset for a new post when no struct is given" do
      %Ecto.Changeset{} = cs = Blog.change_post(%Post{})
      refute cs.valid?
    end

    test "returns a loaded changeset for when an existing post is given" do
      {:ok, post} =
        BlogFixtures.blog_attrs()
        |> Blog.create_post()

      cs = Blog.change_post(post)
      assert cs.valid?
    end
  end

  describe "create_post/1" do
    test "iframe tag is allowed to render in create" do
      # make a post
      {:ok, post} =
        BlogFixtures.blog_attrs(markdown: "<iframe src=https://foo.com></iframe>")
        |> Blog.create_post()

      assert post.html =~ "<iframe"
    end

    test "iframe allow attribute is forced to picture-in-picture only" do
      {:ok, post} =
        BlogFixtures.blog_attrs(
          markdown:
            ~s|<iframe src="https://youtube.com/embed/x" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"></iframe>|
        )
        |> Blog.create_post()

      assert post.html =~ ~s|allow="picture-in-picture"|
      refute post.html =~ "accelerometer"
      refute post.html =~ "clipboard-write"
      refute post.html =~ "web-share"
    end

    test "iframe survives an update on an existing post" do
      {:ok, post} =
        BlogFixtures.blog_attrs(markdown: "no embed yet")
        |> Blog.create_post()

      {:ok, updated} =
        Jamie.Blog.update_post(post, %{
          markdown: ~s|<iframe src="https://foo.com"></iframe>|
        })

      assert updated.html =~ "<iframe"
    end

    test "post gets a slug" do
      # make a post
      {:ok, post} =
        BlogFixtures.blog_attrs(title: "Two Cats Need  Food")
        |> Blog.create_post()

      assert post.slug == "two-cats-need-food"
    end

    test "posts create with required fields" do
      # there are no blog posts
      assert 0 == Repo.aggregate(Jamie.Blog.Post, :count)

      # now make one
      BlogFixtures.blog_attrs()
      |> Blog.create_post()

      # now there is one
      assert 1 == Repo.aggregate(Jamie.Blog.Post, :count)
    end

    test "all fields need to be present in order to save" do
      # blank map
      attrs = %{}
      cs = %Ecto.Changeset{valid?: false} = Blog.create_post(attrs)

      # three errors
      assert Keyword.has_key?(cs.errors, :title)
      assert Keyword.has_key?(cs.errors, :description)
      assert Keyword.has_key?(cs.errors, :markdown)

      # add in title
      attrs = Map.put(attrs, :title, "Done")
      cs = %Ecto.Changeset{valid?: false} = Blog.create_post(attrs)

      # two errors
      assert Keyword.has_key?(cs.errors, :description)
      assert Keyword.has_key?(cs.errors, :markdown)

      # add in description
      attrs = Map.put(attrs, :description, "Done")
      cs = %Ecto.Changeset{valid?: false} = Blog.create_post(attrs)

      # two errors
      assert Keyword.has_key?(cs.errors, :markdown)

      # add in markdown - valid
      attrs = Map.put(attrs, :markdown, "Done")
      {:ok, %Blog.Post{}} = Blog.create_post(attrs)
    end

    test "html is generated when the post saves" do
      # now make one
      attrs = BlogFixtures.blog_attrs(markdown: "# Hello")
      {:ok, post} = Blog.create_post(attrs)

      # it's present when returned
      assert post.html ==
               "<h1><a href=\"#hello\" aria-hidden=\"true\" class=\"anchor\" id=\"hello\"></a>Hello</h1>"

      # and it's persisted into the database
      post = Jamie.Repo.get(Blog.Post, post.id)

      assert post.html ==
               "<h1><a href=\"#hello\" aria-hidden=\"true\" class=\"anchor\" id=\"hello\"></a>Hello</h1>"
    end
  end
end
