defmodule Follower do
	
def start(s) do
	s = State.role(s, :FOLLOWER)
	Follower.start_timeout(s)
end

def start_timeout(s) do
	timer_ref = Server.start_election_timeout(s)
	Follower.next(s, timer_ref)
end

def next(s, timer_ref) do
	receive do
		# become candidate on time out
		{ :ELECTION_TIMEOUT } -> Candidate.start(s)

		# respond to heartbeats
		# reset timeout on valid heartbeat request
		{ :APPEND_REQ, :HEARTBEAT_REQ, server_state } ->
			{ replied, s } = Append.process_heartbeat_request(s, server_state)
			
			if replied do
				# if replied, that means there is leader, thus reset timeout
				Server.stop_timeout(timer_ref)
				Follower.start_timeout(s)
			else
				Follower.next(s, timer_ref)
			end

		# reply to vote requests
		{ :VOTE_REQ, server_state } ->
			Monitor.debug(s, 1, "Follower #{s.id} received vote request from Candidate #{server_state.id}")
			{ _, s } = Vote.process_vote_request(s, server_state)
			Follower.next(s, timer_ref)
	end
end

end