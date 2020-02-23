defmodule Leader do
	
def start(s) do
	s = State.role(s, :LEADER)
	Monitor.debug(s, 2, "Server #{s.id} becomes LEADER in term #{s.curr_term}")

	Monitor.log(s, System.monotonic_time(), "Server #{s.id} now LEADER in term #{s.curr_term}")

	# kill self
	if s.config.leader_crashing_enabled do Process.send_after(s.selfP, { :CRASH }, s.config.leader_crash_after) end

	Leader.send_heartbeats(s)
end

def send_heartbeats(s) do
	Server.broadcast(s, { :APPEND_REQ, :HEARTBEAT_REQ, s })
	timer_ref = Process.send_after(s.selfP, { :HEARTBEAT }, s.config.append_entries_timeout)
	Leader.next(s, timer_ref)
end

def next(s, timer_ref) do
	receive do
		{ :CRASH } -> 
			Server.stop_timeout(timer_ref)
			crash(s)

		# heartbeat maintenance
		{ :HEARTBEAT } ->	Leader.send_heartbeats(s)

		# look out for better leaders (RPC rejetions)
		{ :APPEND_REP, { :HEARTBEAT_REP, false }, server_state } -> 
			Server.stop_timeout(timer_ref)

			# Monitor.log(s, System.monotonic_time(), "Server #{s.id} steps down from LEADER because of RPC rejection from server #{server_state.id}")
			
			Follower.start(s)

		# respond to heartbeats
		# if accepted, another valid leader is present, thus turn into follower
		{ :APPEND_REQ, :HEARTBEAT_REQ, server_state } ->
			{ accepted, s } = Append.process_heartbeat_request(s, server_state)
			if accepted do
				Server.stop_timeout(timer_ref)
				
				# Monitor.log(s, System.monotonic_time(), "Server #{s.id} steps down from LEADER because of submssion")
				
				Follower.start(s)
			else
				Leader.next(s, timer_ref)
			end

		# respond to vote requests
		# if voted, another better leader is present, thus turn into follower
		{ :VOTE_REQ, server_state } ->
			{ voted, s } = Vote.process_vote_request(s, server_state)
			if voted do
				Server.stop_timeout(timer_ref)
				
				# Monitor.log(s, System.monotonic_time(), "Server #{s.id} steps down from LEADER because new election started")
				
				Follower.start(s)
			else
				Leader.next(s, timer_ref)
			end
	end
end

def crash(s) do
	Monitor.log(s, System.monotonic_time(), "LEADER #{s.id} is killed")
end

end