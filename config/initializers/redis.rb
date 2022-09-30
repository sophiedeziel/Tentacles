# frozen_string_literal: true

REDIS_POOL = ConnectionPool::Wrapper.new(size: 5, timeout: 3) { Redis.new }
