defmodule Monitarium.Prometheus do
  use PromEx.Plugin

  @impl PromEx.Plugin
  def event_metrics(opts) do
    events = Keyword.fetch!(opts, :events)
    prefix = Keyword.fetch!(opts, :prefix)

    counters =
      events
      |> Enum.filter(fn {_event, opts} ->
        metrics_cfg = Keyword.get(opts, :metrics, [])
        :counter in metrics_cfg
      end)
      |> Enum.map(fn {event, opts} ->
        name = Keyword.get(opts, :plural, event)
        labels = Keyword.get(opts, :labels, [])
        counter([prefix] ++ name ++ [:total], event_name: event, tags: labels)
      end)

    histograms =
      events
      |> Enum.reduce([], fn {event, opts}, histograms ->
        Keyword.get(opts, :metrics, [])
        |> Enum.find_value(fn
          {:histogram, histogram_opts} ->
            name = Keyword.get(opts, :plural, event)
            labels = Keyword.get(opts, :labels, [])
            measurement = Keyword.fetch!(histogram_opts, :label)

            metric =
              distribution([prefix] ++ name ++ [measurement],
                event_name: event,
                tags: labels,
                measurement: measurement,
                reporter_options: [buckets: Keyword.fetch!(histogram_opts, :buckets)]
              )

            metric

          _ ->
            nil
        end)
        |> case do
          nil -> histograms
          metric -> [metric | histograms]
        end
      end)

    [
      Event.build(:monitarium_event_counters, counters),
      Event.build(:monitarium_histograms, histograms)
    ]
  end

  def generate_child_spec(otp_app, events) do
    quote do
      def prom_ex_plugin(),
        do: {Monitarium.Prometheus, events: unquote(events), prefix: unquote(otp_app)}
    end
  end
end
