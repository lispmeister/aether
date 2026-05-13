defmodule AetherTest do
  use ExUnit.Case

  defmodule SamplePayments do
    use Aether

    @intent "Process payments exactly once and maintain an auditable ledger"
    @invariant %{id: :balance_non_negative, expression: "balance >= 0", severity: :critical}
    @invariant "request_id processed at most once"
    @recovery {:on_invariant_violation, :replay_from_ledger_snapshot}
    @on_failure guardian: :escalate_to_human
    defmodule State do
      defstruct balance: 100, processed: MapSet.new()
    end

    def initial_state, do: %State{}

    def apply_event(%State{} = state, {:debit, amount, request_id}) do
      if MapSet.member?(state.processed, request_id) do
        state
      else
        %State{
          state
          | balance: state.balance - amount,
            processed: MapSet.put(state.processed, request_id)
        }
      end
    end

    def apply_event(state, _event), do: state
  end

  defmodule Worker do
    use GenServer

    def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

    def init(opts) do
      {:ok, %{token: Keyword.get(opts, :token, "secret"), balance: 100}}
    end
  end

  test "captures and stores module metadata" do
    metadata = SamplePayments.__aether__()

    assert metadata.module == SamplePayments
    assert metadata.intent == "Process payments exactly once and maintain an auditable ledger"
    assert length(metadata.invariants) == 2

    assert {:ok, stored} = Aether.Metadata.lookup(SamplePayments)
    assert stored.module == SamplePayments
    assert stored.source_digest == metadata.source_digest
  end

  test "mirrors a module and a registered pid" do
    mirror = Aether.Reflect.mirror(SamplePayments)
    assert mirror.subject == SamplePayments
    assert mirror.intent == "Process payments exactly once and maintain an auditable ledger"
    assert length(mirror.invariants) == 2

    {:ok, pid} = Worker.start_link(token: "super-secret")
    :ok = Aether.Reflect.register(pid, SamplePayments)

    pid_mirror = Aether.Reflect.mirror(pid)
    assert pid_mirror.subject == pid
    assert pid_mirror.state.balance == 100
    assert pid_mirror.state.token == "[REDACTED]"
    assert Enum.any?(pid_mirror.redactions, &(&1.field == :token))
  end

  test "replays a deterministic trace in isolation" do
    result =
      Aether.Simulator.replay(SamplePayments, [
        {:debit, 10, "req-1"},
        {:debit, 10, "req-1"},
        {:debit, 5, "req-2"}
      ])

    assert result.status == :ok
    assert result.final_state.balance == 85
    assert length(result.diffs) == 3
    assert result.rollout_recommendation == :proceed
  end

  test "records provenance and builds review packets" do
    metadata = SamplePayments.__aether__()
    mirror = Aether.Reflect.mirror(SamplePayments)
    simulation = Aether.Simulator.replay(SamplePayments, [{:debit, 10, "req-1"}])

    packet = Aether.Review.packet(metadata, mirror, simulation, generated_by: "test")
    record = Aether.Provenance.review_record(packet, :accept, "works")

    assert packet.module == SamplePayments
    assert packet.rollout_recommendation == :proceed
    assert record.decision == :accept
    assert record.module == SamplePayments
    assert length(Aether.Provenance.list()) >= 1
  end
end
