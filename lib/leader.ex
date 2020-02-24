defmodule Leader do
	
def start(s) do
	s = State.role(s, :LEADER)
	Monitor.debug(s, 2, "Server #{s.id} becomes LEADER in term #{s.curr_term}")

	Monitor.log(s, "Server #{s.id} is LEADER")

	# kill self
	if s.config.leader_crashing_enabled do Process.send_after(s.selfP, { :CRASH }, s.config.leader_crash_after) end

	# dummy heartbeat initialisation
	s = if s.config.leader_dummy_heartbeat_enabled do start_heartbeats(s) else s end

	Leader.next(s)
end

def next(s) do
	receive do
		{ :CRASH } -> 
			Leader.stop_heartbeats(s)
			crash(s)

		# dummy heartbeat maintenance
		{ :HEARTBEAT } ->
			s = Leader.start_heartbeats(s)
			Leader.next(s)

		# handle requests
		# request structure
		# message = %{clientP: self(), uid: uid, cmd: cmd }
		# cmd  = { :move, amount, account1, account2 }
		# uid  = { c.id, c.cmd_seqnum }              # unique id for cmd
		{ :CLIENT_REQUEST, message } ->
			client = message.clientP
			{ :move, amount, acc1, acc2 } = message.cmd
			{ client_id, client_seq_num } = message.uid
			
			Monitor.log_action(s, %{role: :CLIENT, id: client_id}, "received request from")

			# 

			Leader.next(s)

		# look out for better leaders (RPC rejetions)
		{ :APPEND_REP, { :HEARTBEAT_REP, false }, server_state } -> 
			Leader.stop_heartbeats(s)
			# Monitor.log(s, "Server #{s.id} steps down from LEADER because of RPC rejection from server #{server_state.id}")
			Follower.start(s)

		# respond to heartbeats
		# if accepted, another valid leader is present, thus turn into follower
		{ :APPEND_REQ, :HEARTBEAT_REQ, server_state } ->
			{ accepted, s } = Append.process_heartbeat_request(s, server_state)
			if accepted do
				Leader.stop_heartbeats(s)
				# Monitor.log(s, "Server #{s.id} steps down from LEADER because of submssion")
				Follower.start(s)
			else
				Leader.next(s)
			end

		# respond to vote requests
		# if voted, another better leader is present, thus turn into follower
		{ :VOTE_REQ, server_state } ->
			{ voted, s } = Vote.process_vote_request(s, server_state)
			if voted do
				# Monitor.log(s, "Server #{s.id} steps down from LEADER because new election started")
				Leader.stop_heartbeats(s)
				Follower.start(s)
			else
				Leader.next(s)
			end
	end
end

def send_append_entries() do
	
end

# dummy method to stop others candidates from becoming leaders, returns s
def start_heartbeats(s) do
	Server.broadcast(s, { :APPEND_REQ, :HEARTBEAT_REQ, s })
	timer_ref = Process.send_after(s.selfP, { :HEARTBEAT }, s.config.append_entries_timeout)
	State.dummy_heartbeat_ref(s, timer_ref)
end

def stop_heartbeats(s) do
	if s.dummy_heartbeat_ref != nil, do: Server.stop_timeout(s.dummy_heartbeat_ref)
end

# for simulating leader crashing
def crash(s) do
	Monitor.log(s, "LEADER #{s.id} is killed")
end

end