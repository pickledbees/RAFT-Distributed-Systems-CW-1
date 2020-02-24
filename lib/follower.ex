defmodule Follower do
	
def start(s) do
	s = State.role(s, :FOLLOWER)
	Monitor.debug(s, 2, "Server #{s.id} now FOLLOWER")

	Monitor.log(s, "Server #{s.id} is FOLLOWER")
	
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

		# reply to vote requests
		# if voted, reset timer
		{ :VOTE_REQ, candidate } ->
			{ voted, s } = Vote.process_vote_request(s, candidate)
			if voted do
				Server.stop_timeout(timer_ref)
				Follower.start_timeout(s)
			else
				Follower.next(s, timer_ref)
			end

		# look out for leaders
		{ :APPEND_REQ, leader } ->
			# if valid leader present, process request and continue as follower and reset timeout
			if s.curr_term <= leader.curr_term do
				s = Append.process_append_entries_request(s, leader)
				Server.stop_timeout(timer_ref)
				Follower.start_timeout(s)
			else
				# else reject request and continue as follower
				send leader.selfP, { :APPEND_REP, s.curr_term, false }
				Follower.start_timeout(s)
			end

		# DEV listeners
		#----------------------------------------------------------------------------

		# respond to dummy heartbeats
		# reset timeout on valid heartbeat request
		{ :HEARTBEAT_REQ, server_state } ->
			{ replied, s } = Append.process_heartbeat_request(s, server_state)
			
			if replied do
				# if replied, that means there is leader, thus reset timeout
				Server.stop_timeout(timer_ref)
				Follower.start_timeout(s)
			else
				Follower.next(s, timer_ref)
			end
	end
end

end