defmodule Bitcoin.Observer do
  import Bitcoin.BlockChain
  use GenServer

  def newObserver() do
    {:ok, pid} = GenServer.start_link(__MODULE__, name: :observer)
    IO.inspect(pid)
    pid
  end

  def setNeighbours(pid, neighbours) do
    GenServer.cast(pid, {:setNeighbours, neighbours})
  end

  def setChain(chain) do
    GenServer.cast(:observer, {:setChain, chain})
  end

  def getChain() do
    GenServer.call(:observer, {:getChain}, 10_000_000)
  end

  def startSimulation(_pid, _chain, _timeInterval \\ 10) do
    IO.inspect("Observer simulation.")
  end

  def init(_args) do
    {:ok, %{"neighbours" => [], "pendingTransactions" => []}}
  end

  def handle_cast({:setNeighbours, neighbours}, state) do
    state = Map.put(state, "neighbours", neighbours)
    {:noreply, state}
  end

  def handle_cast({:setChain, chain}, state) do
    state = Map.put(state, "blockchain", chain)
    {:noreply, state}
  end

  def handle_cast({:blockchainBroadcast, chain}, state) do
    try do
      isChainValid(chain)

      chain =
        if Map.get(state, "blockchain") == nil do
          chain
        else
          if length(Map.get(state, "blockchain").chain) >= length(chain.chain) do
            Map.get(state, "blockchain")
          else
            chain
          end
        end

      receivedTxn = Map.get(state, "pendingTransactions")

      txns =
        Enum.reduce(receivedTxn, [], fn x, acc ->
          if(x.timestamp > List.last(chain.chain).timestamp) do
            acc ++ [x]
          else
            acc
          end
        end)

      state = Map.put(state, "pendingTransactions", txns)
      {:noreply, Map.put(state, "blockchain", chain)}
    catch
      x ->
        IO.inspect("Invalid Blockchain: #{x}")
        {:noreply, state}
    end
  end

  def handle_cast({:transactionBroadcast, _txn}, state) do
    {:noreply, state}
  end

  def handle_call({:getNeighbours}, _from, state) do
    {:reply, Map.get(state, "neighbours"), state}
  end

  def handle_call({:getChain}, _from, state) do
    {:reply, Map.get(state, "blockchain"), state}
  end

  def handle_call({:getPendingTransactions}, _from, state) do
    {:reply, Map.get(state, "pendingTransactions"), state}
  end
end
