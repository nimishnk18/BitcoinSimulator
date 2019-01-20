defmodule Bitcoin.BlockChain do
  import Bitcoin.Bitcoin
  import Bitcoin.Transaction

  defstruct chain: [newBlock("1/1/2018", [], 0)],
            difficulty: 2,
            miningRewards: 100,
            pendingTransactions: []

  def newChain do
    %Bitcoin.BlockChain{}
  end

  def minePendingTransactions(blockchain, miningRewardAddress) do
    miningFee = Enum.reduce(blockchain.pendingTransactions, 0, fn x, acc -> acc + x.fee end)

    blockchain =
      addTransaction(
        blockchain,
        newTransaction(nil, miningRewardAddress, blockchain.miningRewards + miningFee)
      )

    block =
      newBlock(
        DateTime.to_string(DateTime.utc_now()),
        blockchain.pendingTransactions,
        List.last(blockchain.chain).currentHash
      )

    block = mineBlock(block, blockchain.difficulty)

    blockchain = %{blockchain | chain: blockchain.chain ++ [block]}
    %{blockchain | pendingTransactions: []}
  end

  def getBalanceofAddress(blockchain, address) do
    if blockchain == nil do
      0
    else
      blocks = blockchain.chain

      Enum.reduce(blocks, 0, fn x, acc ->
        transactions = x.transactions

        acc +
          Enum.reduce(transactions, 0, fn k, minacc ->
            cond do
              k.fromAddress == k.toAddress -> minacc
              k.fromAddress == address -> minacc - k.amount - k.fee
              k.toAddress == address -> minacc + k.amount
              true -> minacc
            end
          end)
      end)
    end
  end

  def addTransaction(chain, transaction) do
    if transaction.fromAddress == "" or transaction.toAddress == "" do
      throw("Transaction must include from and to address")
    end

    if !isValid(transaction) do
      throw("Cannot add invalid transaction to the chain")
    end

    %{chain | pendingTransactions: chain.pendingTransactions ++ [transaction]}
  end

  def isChainValid(blockchain) do
    if blockchain == nil do
      false
    else
      blocks = blockchain.chain

      Enum.reduce(Enum.slice(blocks, 1, length(blocks)), true, fn x, acc ->
        previous = Enum.at(blocks, Enum.find_index(blocks, fn k -> x == k end) - 1)

        cond do
          !hasValidTransactions(x) -> acc and false
          getNewHash(x) != x.currentHash -> acc and false
          x.previousHash != previous.currentHash -> acc and false
          true -> acc and true
        end
      end)
    end
  end
end
