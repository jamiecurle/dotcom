defmodule JamieWeb.MailingListComponents do
  @moduledoc """
  The parts of the mailing list forms that signing up and managing a
  subscription share: which worlds, and how often.
  """
  use Phoenix.Component

  alias Jamie.MailingList
  alias Jamie.MailingList.Subscriber

  # what the forms say about each world
  @blurbs %{
    "treeworld" => "Woodland, trees and the land",
    "techworld" => "Software, the web and tools",
    "makerworld" => "The workshop and making things",
    "privacyworld" => "Privacy, data and the law",
    "foodworld" => "Cooking and eating",
    "miscworld" => "Everything else"
  }

  @doc """
  The worlds (or everything) and frequency fieldsets, for a form built
  from a `Subscriber` changeset.
  """
  attr :form, Phoenix.HTML.Form, required: true

  def preferences(assigns) do
    assigns =
      assign(assigns,
        worlds: Enum.map(MailingList.worlds(), &{&1, @blurbs[&1]}),
        frequencies: Subscriber.frequencies(),
        everything?: assigns.form[:everything].value in [true, "true"],
        chosen: assigns.form[:worlds].value || []
      )

    ~H"""
    <fieldset id="subscribe-worlds">
      <legend>Worlds</legend>
      <%!-- unticked boxes send nothing, so this blank always goes, letting
           "no worlds" replace the saved ones (the changeset drops it) --%>
      <input type="hidden" name={@form[:worlds].name <> "[]"} value="" />
      <ol class="worlds">
        <li>
          <input type="hidden" name={@form[:everything].name} value="false" />
          <label class="world everything" for="subscriber-everything">
            <input
              type="checkbox"
              id="subscriber-everything"
              name={@form[:everything].name}
              value="true"
              checked={@everything?}
            />
            <span class="name">Everything</span>
            <span class="blurb">All of it, and any world to come</span>
          </label>
        </li>
        <li :for={{world, blurb} <- @worlds}>
          <label class="world" for={"subscriber-world-#{world}"}>
            <input
              type="checkbox"
              id={"subscriber-world-#{world}"}
              name={@form[:worlds].name <> "[]"}
              value={world}
              checked={world in @chosen}
              disabled={@everything?}
            />
            <span class="name">{world}</span>
            <span class="blurb">{blurb}</span>
          </label>
        </li>
      </ol>
      <p :for={msg <- errors(@form[:worlds])} class="error">{msg}</p>
    </fieldset>

    <fieldset id="subscribe-frequency">
      <legend>How often</legend>
      <div class="frequencies">
        <label :for={frequency <- @frequencies} for={"subscriber-frequency-#{frequency}"}>
          <input
            type="radio"
            id={"subscriber-frequency-#{frequency}"}
            name={@form[:frequency].name}
            value={frequency}
            checked={to_string(@form[:frequency].value) == to_string(frequency)}
          />
          <span>{frequency_label(frequency)}</span>
        </label>
      </div>
    </fieldset>
    """
  end

  @doc "When each frequency goes out, as the forms put it."
  def frequency_label(:daily), do: "Daily, 8am"
  def frequency_label(:weekly), do: "Weekly, Fridays"
  def frequency_label(:monthly), do: "Monthly, the 28th"

  @doc """
  A field's errors, once it has been touched (as `<.input>` does) or the
  form submitted. An empty set of checkboxes sends nothing, so it never
  counts as touched; the submit is what shows its error.
  """
  def errors(field) do
    if Phoenix.Component.used_input?(field) or field.form.source.action in [:insert, :update],
      do: Enum.map(field.errors, &JamieWeb.CoreComponents.translate_error/1),
      else: []
  end
end
