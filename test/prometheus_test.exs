defmodule PrometheusTest do
  use ExUnit.Case, async: true

  import Plug.Test

  defmodule ExampleEvents do
    use Monitarium, backend: :prometheus, otp_app: :myapp

    event [:widget, :frobnicated], labels: [:widget, :status], metrics: [:counter]
    event [:spline, :reticulated], plural: [:splines, :reticulated], metrics: [:counter]

    event [:foo, :barred],
      labels: [:status],
      metrics: [
        :counter,
        histogram: [label: :duration_s, buckets: [0.1, 1.0, 10.0]]
      ]

    event [:not_a_metric]
  end

  defmodule ExamplePrometheus do
    use PromEx, otp_app: :myapp

    @impl PromEx
    def plugins(), do: [ExampleEvents.prom_ex_plugin()]
  end

  setup do
    start_link_supervised!(ExamplePrometheus)
    :ok
  end

  test "rolls up events into prometheus counters" do
    ExampleEvents.emit([:widget, :frobnicated], %{}, %{widget: "w", status: :success})
    ExampleEvents.emit([:widget, :frobnicated], %{}, %{widget: "w", status: :success})
    ExampleEvents.emit([:widget, :frobnicated], %{}, %{widget: "w", status: :failure})

    conn = get_metrics()

    assert conn.resp_body =~ ~r/^myapp_widget_frobnicated_total{status="success",widget="w"} 2$/m
    assert conn.resp_body =~ ~r/^myapp_widget_frobnicated_total{status="failure",widget="w"} 1$/m
  end

  test "rolls up events into prometheus histogram buckets" do
    ExampleEvents.emit([:foo, :barred], %{duration_s: 0.8}, %{status: :success})
    ExampleEvents.emit([:foo, :barred], %{duration_s: 1.2}, %{status: :success})

    conn = get_metrics()

    assert conn.resp_body =~
             ~r/^myapp_foo_barred_duration_s_bucket{status="success",le="0.1"} 0$/m

    assert conn.resp_body =~
             ~r/^myapp_foo_barred_duration_s_bucket{status="success",le="1.0"} 1$/m

    assert conn.resp_body =~
             ~r/^myapp_foo_barred_duration_s_bucket{status="success",le="10.0"} 2$/m
  end

  test "plural forms can be specified" do
    ExampleEvents.emit([:spline, :reticulated])
    conn = get_metrics()

    assert conn.resp_body =~ ~r/^myapp_splines_reticulated_total 1$/m
  end

  test "not all events should be rolled up into counters" do
    ExampleEvents.emit([:not_a_metric])
    conn = get_metrics()

    refute conn.resp_body =~ "not_a_metric"
  end

  defp get_metrics() do
    opts = PromEx.Plug.init(prom_ex_module: ExamplePrometheus)
    conn = conn(:get, "/metrics") |> PromEx.Plug.call(opts)
    assert conn.status == 200
    conn
  end
end
