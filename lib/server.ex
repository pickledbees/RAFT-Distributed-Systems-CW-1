
# distributed algorithms, n.dulay, 4 feb 2020
# coursework, raft consenus, v1

defmodule Server do

# using: s for 'server/state', m for 'message'

def start(config, server_id, databaseP) do
  receive do
  { :BIND, servers } ->
    s = State.initialise(config, server_id, servers, databaseP)
   _s = Server.next(s)
  end # receive
end # start

def next(_s) do
	Follower.start(_s)
end # next

def broadcast(_s, message) do
	for server <- _s.servers do
		send server, message
	end
end

# returns election timer_ref
def start_election_timeout(s) do
	election_timeout = s.config.election_timeout
	Process.send_after(s.selfP, { :ELECTION_TIMEOUT }, Enum.random(election_timeout .. election_timeout * 2))
end

# returns s
def start_rpc_timeouts(s) do
	rec_start_rpc_timeouts(s, s.servers)
end

# recursive function for above
def rec_start_rpc_timeouts(s, servers) do
	if length(servers) == 0 do
		s
	else
		[ serverP | rest ] = servers
		# only set timeouts for other servers
		s = if serverP != s.selfP do start_rpc_timeout_for_server(s, serverP) else s end
		rec_start_rpc_timeouts(s, rest)
	end
end

# returns s
def start_rpc_timeout_for_server(s, serverP) do
	rpc_timeout = round(s.config.election_timeout / 10)
	timer_ref = Process.send_after(s.selfP, { :RPC_TIMEOUT, serverP }, rpc_timeout)
	State.rpc_timer_ref(s, serverP, timer_ref)
end

# returns s
def stop_rpc_timeouts(s) do
	rec_stop_rpc_timeouts(s, s.servers)
end

# recursive function for above
def rec_stop_rpc_timeouts(s, servers) do
	if length(servers) == 0 do
		s
	else
		[ serverP | rest ] = servers
		timer_ref = State.get_rpc_timer_ref(s, serverP)
		# stop only if available
		if timer_ref != nil, do: stop_timeout(timer_ref)
		rec_stop_rpc_timeouts(s, rest)
	end
end

def stop_timeout(timer_ref) do
	Process.cancel_timer(timer_ref)
end

end # Server