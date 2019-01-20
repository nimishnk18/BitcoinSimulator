defmodule Bitcoin.Client do
  import Bitcoin.Transaction
  import Bitcoin.BlockChain
  use GenServer

  def newClient() do
    {:ok, pid} = GenServer.start_link(__MODULE__, [])
    GenServer.cast(pid, {:createWallet})
    pid
  end

  def setNeighbours(pid, neighbours) do
    GenServer.cast(pid, {:setNeighbours, neighbours})
  end

  def setChain(pid, chain) do
    GenServer.cast(pid, {:setChain, chain})
  end

  def startSimulation(pid, chain, shouldTrade, timeInterval \\ 10) do
    Task.async(fn -> simulate(pid, chain, shouldTrade, timeInterval) end)
  end

  def simulate(pid, chain, shouldTrade, timeInterval) do

    neighbours = GenServer.call(pid, {:getNeighbours}, 1_000_000)
    address = getWalletAddress(pid)

    chain =
      if shouldTrade == 0 do
        chain =
          try do
            balance = Bitcoin.BlockChain.getBalanceofAddress(chain, address)

            chain =
              if balance > 0 do
                txn =
                  createTransaction(
                    pid,
                    getWalletAddress(Enum.random(neighbours)),
                    Enum.random(1..balance)
                  )

                chain = addTransaction(chain, txn)
                neighbours = neighbours ++ [:observer]

                Enum.each(neighbours, fn x ->
                  GenServer.cast(x, {:transactionBroadcast, txn})
                end)

                GenServer.cast(pid, {:transactionBroadcast, txn})

                chain
              else
                chain
              end

            chain
          catch
            x ->
              chain
          end

        chain
      else
        chain
      end

    GenServer.cast(pid, {:blockchainBroadcast, chain})

    :timer.sleep(2000)

    chain =
      try do
        receivedTransactions = GenServer.call(pid, {:getPendingTransactions}, 1_000_000)

        txns =
          Enum.reduce(receivedTransactions, [], fn x, acc ->
            if(x.timestamp > List.last(chain.chain).timestamp) do
              acc ++ [x]
            else
              acc
            end
          end)

        GenServer.cast(pid, {:setPendingTransaction, []})

        chain = GenServer.call(pid, {:getChain}, 1000000)

        chain =
          Enum.reduce(txns, chain, fn x, acc ->
            acc = addTransaction(acc, x)
          end)

        chain = minePendingTransactions(chain, address)
        neighbours = neighbours ++ [:observer]

        Enum.each(neighbours, fn x ->
          GenServer.cast(x, {:blockchainBroadcast, chain})
        end)

        chain
      catch
        x ->
          chain
      end

    :timer.sleep(1000)
    simulate(pid, chain, rem(shouldTrade + 1, 10), timeInterval)
  end

  def createTransaction(pid, toAddress, amount, fee \\ 0) do
    GenServer.call(pid, {:createTransaction, [toAddress, amount, fee]}, 1_000_000)
  end

  def getWalletAddress(pid) do
    GenServer.call(pid, {:getWalletAddress}, 1_000_000)
  end

  def init(_args) do
    {:ok, %{}}
  end

  def handle_cast({:setNeighbours, neighbours}, state) do
    state = Map.put(state, "neighbours", neighbours)
    {:noreply, state}
  end

  def handle_cast({:setPendingTransaction, txn}, state) do
    state = Map.put(state, "pendingTransactions", txn)
    {:noreply, state}
  end

  def handle_cast({:transactionBroadcast, txn}, state) do
    state = Map.put(state, "pendingTransactions", Map.get(state, "pendingTransactions") ++ [txn])
    {:noreply, state}
  end

  def handle_cast({:blockchainBroadcast, chain}, state) do
    try do
      if isChainValid(chain) do
        chain =
          if Map.get(state, "blockchain") == %{} do
            chain
          else
            if length(Map.get(state, "blockchain").chain) >= length(chain.chain) do
              Map.get(state, "blockchain")
            else
              chain
            end
          end

        {:noreply, Map.put(state, "blockchain", chain)}
      else
        {:noreply, state}
      end
    catch
      x ->
        IO.inspect("Invalid Blockchain: #{x}")
        {:noreply, state}
    end
  end
  def handle_cast({:setChain, chain}, state) do
    state = Map.put(state, "blockchain", chain)
    {:noreply, state}
  end

  def handle_cast({:createWallet}, _state) do
    {walletAddress, privateKey} = :crypto.generate_key(:ecdh, :secp256k1)

    {:noreply,
     %{
       "walletAddress" => walletAddress,
       "privateKey" => privateKey,
       "pendingTransactions" => [],
       "pendingBlocks" => [],
       "blockchain" => %{}
     }}
  end

  def handle_call({:createTransaction, [toAddress, amount, fee]}, _from, state) do
    txn = newTransaction(Map.get(state, "walletAddress"), toAddress, amount, fee)
    txn = signTransaction(txn, Map.get(state, "walletAddress"), Map.get(state, "privateKey"))
    {:reply, txn, state}
  end

  def handle_call({:getWalletAddress}, _from, state) do
    {:reply, Map.get(state, "walletAddress"), state}
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
