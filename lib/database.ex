
# distributed algorithms, n.dulay 4 feb 2020
# coursework, raft consensus, v1

defmodule Database do

def start(config, server_id) do
  # db is state of database
  db = %{
    config: config,
    # DB uses server_id to identify itself, should prefix with 'DB' on debug
    server_id: server_id, 
    seqnum: 0, 
    balances: Map.new
  }

  # pass db state into 'next' function
  Database.next(db)
end # start

# setters
def seqnum(db, v), do: Map.put(db, :seqnum, v)
def balances(db, i, v), do:
    Map.put(db, :balances, Map.put(db.balances, i, v))

def next(db) do
  receive do
  { :EXECUTE, command } ->  # should send a result back, but assuming always okay

    # literally moving amount from account1 to account2
    { :move, amount, account1, account2 } = command

    # get balance from db.balances belonging to account1, return 0 by default
    balance1 = Map.get db.balances, account1, 0

    # get balance from db.balances belonging to account2, return 0 by default
    balance2 = Map.get db.balances, account2, 0

    # perform amount xfer
    db = Database.balances(db, account1, balance1 + amount)
    db = Database.balances(db, account2, balance2 - amount)

    db = Database.seqnum(db, db.seqnum + 1)

    Monitor.notify db, { :DB_MOVE, db.server_id, db.seqnum, command }

    Database.next(db)
  unexpected ->
    Monitor.halt(db, "Database: unexpected message #{inspect unexpected}")
  end # receive
end # next

end # Database
