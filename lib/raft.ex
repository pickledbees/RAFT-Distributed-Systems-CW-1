
# distributed algorithms, n.dulay, 4 feb 2020
# coursework, raft consensus, v1

defmodule Raft do

# main start, calls other raft.start depending on arguments passed in terminal run
def start do
  config = DAC.node_init()
  IO.puts "Raft at #{DAC.node_ip_addr}"

  Raft.start(config.start_function, config)
end # start/0

def start(:multi_node_wait, _), do: :skip

def start(:multi_node_start, config) do

  IO.puts "NOTE: No clients are being spawned, uncomment to spawn"

  # spawn monitor process in top-level raft node
  monitorP = spawn(Monitor, :start, [config])

  # hold reference to monitor in the monitorP key of the config
  # only accesed by Monitor module to pass mesages to currently spawned monitor process
  config   = Map.put(config, :monitorP, monitorP)

  # co-locate 1 server and 1 database at each server node
  # by assigning same pid to both processes spawned, they run in the same process
  # messages sent will be recieved by both sets of functions
  servers = for id <- 1 .. config.n_servers do
    databaseP = Node.spawn(:'server#{id}_#{config.node_suffix}', 
                     Database, :start, [config, id])
    _serverP  = Node.spawn(:'server#{id}_#{config.node_suffix}', 
                     Server, :start, [config, id, databaseP])
  end # for

  # pass list of servers to each server
  for server <- servers do
    send server, { :BIND, servers }
  end

  # create 1 client at each client node
  # for id <- 1 .. config.n_clients do
  #   _clientP = Node.spawn(:'client#{id}_#{config.node_suffix}', 
  #                   Client, :start, [config, id, servers])
  # end # for

end

end # module ------------------------------


