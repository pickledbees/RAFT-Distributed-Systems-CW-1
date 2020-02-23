
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

def start_election_timeout(s) do
	election_timeout = s.config.election_timeout
	Process.send_after(s.selfP, { :ELECTION_TIMEOUT }, Enum.random(election_timeout .. election_timeout * 2))
end

def stop_timeout(timer_ref) do
	Process.cancel_timer(timer_ref)
end

end # Server