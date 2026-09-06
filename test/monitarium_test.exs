defmodule MonitariumTest do
  use ExUnit.Case, async: true

  defmodule Example do
    use Monitarium, backend: :prometheus, otp_app: :myapp

    event [:widget, :frobnicated], labels: [:widget, :status]
    event [:billy, :no, :options]
  end

  test "returns available events" do
    assert Example.events() == [
             [:billy, :no, :options],
             [:widget, :frobnicated]
           ]
  end

  test "emits a telemetry event" do
    ref = :telemetry_test.attach_event_handlers(self(), Example.events())

    Example.emit([:widget, :frobnicated], %{duration_s: 1.2}, %{
      widget: "w",
      status: :success
    })

    assert_received {[:widget, :frobnicated], ^ref, %{duration_s: 1.2},
                     %{widget: "w", status: :success}}
  end

  test "options are optional" do
    ref = :telemetry_test.attach_event_handlers(self(), Example.events())
    Example.emit([:billy, :no, :options])
    assert_received {[:billy, :no, :options], ^ref, _, _}
  end

  test "raises when emitting an undeclared event" do
    assert_raise FunctionClauseError, fn -> Example.emit([:subtle, :typo], %{}, %{}) end
  end

  test "raises when emitting an event without all required labels" do
    assert_raise RuntimeError, fn ->
      Example.emit([:widget, :frobnicated], %{}, %{widget: "w"})
    end
  end
end
