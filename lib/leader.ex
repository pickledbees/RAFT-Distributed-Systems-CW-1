defmodule Leader do
	
def start(s) do
	s = State.role(s, :LEADER)
	Monitor.debug(s, 2, "Server #{s.id} becomes LEADER in term #{s.curr_term}")
	Monitor.log(s, "Server #{s.id} is LEADER")

	# dev calls
	if s.config.leader_crashing_enabled do Process.send_after(s.selfP, { :CRASH }, s.config.leader_crash_after) end # kill self
	
	# allow for switching between dummy heartbeat and actual heartbeat RPC
	s = if s.config.leader_dummy_heartbeat_enabled do
		start_heartbeats(s)
	else 
		# normal RPC
		s = Server.stop_rpc_timeouts(s)	# start the timeouts, cancel any if inside
		Append.send_append_entries_to_all_but_self(s)
	end # dummy heartbeat initialisation

	Leader.next(s)
end

def next(s) do
	receive do
		{ :RPC_TIMEOUT, serverP } -> 
			s = Append.send_append_entries(s, serverP)
			Leader.next(s)

		{ :CLIENT_REQUEST, message } ->
			if s.config.leader_dummy_heartbeat_enabled do
				# ignore requests
				Leader.next(s)
			else
				client = message.clientP
				{ :move, amount, acc1, acc2 } = message.cmd
				{ client_id, client_seq_num } = message.uid
				
				Monitor.log_action(s, %{role: :CLIENT, id: client_id}, "received request from")

				s = State.append_cmd_to_log(s, message.cmd) # append to log

				# Monitor.print_server_state(s, 5, "after appending")

				s = Append.send_append_entries_to_all_but_self(s) # replicate

				Leader.next(s)
			end

		# respond to vote requests
		# if voted, new election started, thus turn into follower
		{ :VOTE_REQ, candidate } ->
			{ voted, s } = Vote.process_vote_request(s, candidate)
			if voted do
				Monitor.log(s, "LEADER #{s.id} steps down from LEADER because newer election started")
				s = Server.stop_rpc_timeouts(s)
				stop_heartbeats(s) # for dummy heartbeats
				Follower.start(s)
			else
				Leader.next(s)
			end

		# look out for other leaders
		{ :APPEND_REQ, leader } ->
			if s.curr_term < leader.curr_term do
				stop_heartbeats(s)
				Server.stop_rpc_timeouts(s)
				s = Append.process_append_entries_request(s, leader)
				Follower.start(s)
			else
				send leader.selfP, { :APPEND_REP, s.curr_term, false }
				Leader.next(s)
			end


		# DEV listeners
		#----------------------------------------------------------------------------

		{ :CRASH } -> 
			# for dummy heartbeats
			stop_heartbeats(s)
			crash(s)

		# dummy heartbeat maintenance
		{ :HEARTBEAT } ->
			s = start_heartbeats(s)
			Leader.next(s)

		# respond to dummy heartbeats
		# if accepted, another valid leader is present, thus turn into follower
		{ :HEARTBEAT_REQ, server_state } ->
			{ accepted, s } = Append.process_heartbeat_request(s, server_state)
			if accepted do
				Monitor.log(s, "Server #{s.id} steps down from LEADER because of submssion")
				stop_heartbeats(s) # for dummy heartbeats
				Server.stop_rpc_timeouts(s)
				Follower.start(s)
			else
				Leader.next(s)
			end

		# look out for better leaders (RPC rejetions)
		{ :HEARTBEAT_REP, false, server_state } -> 
			Monitor.log(s, "Server #{s.id} steps down from LEADER because of RPC rejection from server #{server_state.id}")
			stop_heartbeats(s) # for dummy heartbeats
			Server.stop_rpc_timeouts(s)
			Follower.start(s)
	end
end

# dummy method to stop others candidates from becoming leaders, returns s
def start_heartbeats(s) do
	Server.broadcast(s, { :HEARTBEAT_REQ, s })
	timer_ref = Process.send_after(s.selfP, { :HEARTBEAT }, s.config.dummy_heart_beat_timeout)
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