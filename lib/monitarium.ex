defmodule Monitarium do
  alias Monitarium.Prometheus

  defmacro __using__(opts) do
    {backend, opts} = Keyword.pop(opts, :backend)

    quote do
      import Monitarium

      Module.register_attribute(__MODULE__, :events, accumulate: true)
      @monitarium {unquote(backend), unquote(opts)}
      @before_compile Monitarium
    end
  end

  defmacro event(name, opts \\ []) do
    quote do
      @events {unquote(name), unquote(opts)}
    end
  end

  defmacro __before_compile__(env) do
    events = env.module |> Module.get_attribute(:events)

    emit_decl =
      quote do
        def emit(event, measurements \\ %{}, metadata \\ %{})
      end

    emit_fns =
      events
      |> Enum.map(fn {event, opts} ->
        labels = Keyword.get(opts, :labels, [])

        quote do
          def emit(unquote(event) = event, measurements, metadata) do
            if not Enum.all?(unquote(labels), &Map.has_key?(metadata, &1)) do
              raise "event #{inspect(event)} missing label"
            end

            :telemetry.execute(event, measurements, metadata)
          end
        end
      end)

    events_fn =
      quote do
        def events(), do: @events |> Enum.map(fn {event, _} -> event end)
      end

    {backend, opts} = env.module |> Module.get_attribute(:monitarium)

    setup_fn =
      case backend do
        :prometheus ->
          otp_app = Keyword.fetch!(opts, :otp_app)
          Prometheus.generate_child_spec(otp_app, events)
      end

    quote do
      (unquote_splicing([setup_fn, events_fn, emit_decl | emit_fns]))
    end
  end
end
