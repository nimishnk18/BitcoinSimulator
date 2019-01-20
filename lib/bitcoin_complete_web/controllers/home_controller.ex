defmodule BitcoinCompleteWeb.HomeController do
  use BitcoinCompleteWeb, :controller
  alias Bitcoin.Client
  alias Bitcoin.Observer
  alias Bitcoin.BlockChain

  def index(conn, _params) do
    render(conn, "index.html", token: get_csrf_token())
  end

  def start(conn, params) do
    pid = Observer.newObserver()

    try do
      Process.register(pid, :observer)
    rescue
      _ ->
        Process.unregister(:observer)
        Process.register(pid, :observer)
    end

    {n, _} = Integer.parse(Map.get(params, "number"))
    nodes = Enum.map(1..n, fn _ -> Client.newClient() end)
    chain = BlockChain.newChain()
    randomNode = Enum.random(nodes)
    chain = BlockChain.minePendingTransactions(chain, Client.getWalletAddress(randomNode))

    chain =
      Enum.reduce(nodes, chain, fn x, chain ->
        txn = Client.createTransaction(randomNode, Client.getWalletAddress(x), 10)
        chain = BlockChain.addTransaction(chain, txn)
      end)

    chain = BlockChain.minePendingTransactions(chain, Client.getWalletAddress(randomNode))
    # Observer.setChain(chain)
    # nodes = nodes ++ [:observer]
    Enum.each(nodes, fn x ->
      Client.setChain(x, chain)
      Client.setNeighbours(x, List.delete(nodes, x))
      Client.startSimulation(x, chain, rem(Enum.find_index(nodes, fn k -> k == x end), 10))
    end)

    render(conn, "charts.html")
  end

  def getData() do
    chain = Observer.getChain()

    if chain != nil do
      total =
        Enum.reduce(chain.chain, 0, fn x, acc ->
          acc =
            acc +
              if x.transactions != nil do
                length(x.transactions)
              else
                0
              end
        end)

        coins =
        Enum.reduce(chain.chain, 0, fn x, acc ->
          acc =
            acc +
              if x.transactions != nil do
                Enum.reduce(x.transactions, 0, fn x, acc ->
                  acc+x.amount
                end)
              else
                0
              end
        end)

      %{
        "num_blocks" => length(chain.chain),
        "num_txn" => total,
        "num_coins" => coins,
      }
    else
      %{
        "num_blocks" => 0,
        "num_txn" => 0,
        "num_coins" => 0
      }
    end
  end
end
