# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `mini_racer` gem.
# Please instead update this file by running `bin/tapioca gem mini_racer`.


# This code used to be shared in lib/mini_racer.rb
# but was moved to the extension with https://github.com/rubyjs/mini_racer/pull/325.
# So now this is effectively duplicate logic with C/C++ code.
# Maybe one day it can be actually shared again between both backends.
#
# source://mini_racer//lib/mini_racer/version.rb#3
module MiniRacer; end

# eval is defined in the C class
#
# source://mini_racer//lib/mini_racer.rb#67
class MiniRacer::Context
  # @return [Context] a new instance of Context
  #
  # source://mini_racer//lib/mini_racer.rb#22
  def initialize(*_arg0); end

  # @raise [ContextDisposedError]
  #
  # source://mini_racer//lib/mini_racer.rb#22
  def attach(_arg0, _arg1); end

  # source://mini_racer//lib/mini_racer.rb#22
  def call(*_arg0); end

  # source://mini_racer//lib/mini_racer.rb#22
  def dispose; end

  # source://mini_racer//lib/mini_racer.rb#22
  def eval(*_arg0); end

  # source://mini_racer//lib/mini_racer.rb#22
  def heap_snapshot; end

  # @raise [ContextDisposedError]
  #
  # source://mini_racer//lib/mini_racer.rb#22
  def heap_stats; end

  # source://mini_racer//lib/mini_racer.rb#68
  def load(filename); end

  # source://mini_racer//lib/mini_racer.rb#22
  def low_memory_notification; end

  # source://mini_racer//lib/mini_racer.rb#22
  def pump_message_loop; end

  # source://mini_racer//lib/mini_racer.rb#22
  def stop; end

  # source://mini_racer//lib/mini_racer.rb#72
  def write_heap_snapshot(file_or_io); end
end

# source://mini_racer//lib/mini_racer.rb#33
class MiniRacer::ContextDisposedError < ::MiniRacer::Error; end

# source://mini_racer//lib/mini_racer.rb#31
class MiniRacer::Error < ::StandardError; end

# source://mini_racer//lib/mini_racer.rb#36
class MiniRacer::EvalError < ::MiniRacer::Error; end

class MiniRacer::InternalError < ::MiniRacer::EvalError; end

# helper class returned when we have a JavaScript function
class MiniRacer::JavaScriptFunction; end

# source://mini_racer//lib/mini_racer/version.rb#5
MiniRacer::LIBV8_NODE_VERSION = T.let(T.unsafe(nil), String)

module MiniRacer::Loader
  class << self
    # source://mini_racer//lib/mini_racer.rb#10
    def load(_arg0); end
  end
end

# source://mini_racer//lib/mini_racer.rb#37
class MiniRacer::ParseError < ::MiniRacer::EvalError; end

class MiniRacer::Platform
  class << self
    # source://mini_racer//lib/mini_racer.rb#22
    def set_flags!(*_arg0); end
  end
end

# source://mini_racer//lib/mini_racer.rb#34
class MiniRacer::PlatformAlreadyInitialized < ::MiniRacer::Error; end

# source://mini_racer//lib/mini_racer.rb#41
class MiniRacer::RuntimeError < ::MiniRacer::EvalError
  # @return [RuntimeError] a new instance of RuntimeError
  #
  # source://mini_racer//lib/mini_racer.rb#42
  def initialize(message); end

  # source://mini_racer//lib/mini_racer.rb#48
  def backtrace; end
end

# source://mini_racer//lib/mini_racer.rb#38
class MiniRacer::ScriptTerminatedError < ::MiniRacer::EvalError; end

# `size` and `warmup!` public methods are defined in the C class
class MiniRacer::Snapshot
  # @return [Snapshot] a new instance of Snapshot
  #
  # source://mini_racer//lib/mini_racer.rb#22
  def initialize(*_arg0); end

  # source://mini_racer//lib/mini_racer.rb#22
  def dump; end

  # source://mini_racer//lib/mini_racer.rb#22
  def size; end

  # source://mini_racer//lib/mini_racer.rb#22
  def warmup!(_arg0); end
end

# source://mini_racer//lib/mini_racer.rb#54
class MiniRacer::SnapshotError < ::MiniRacer::Error
  # @return [SnapshotError] a new instance of SnapshotError
  #
  # source://mini_racer//lib/mini_racer.rb#55
  def initialize(message); end

  # source://mini_racer//lib/mini_racer.rb#61
  def backtrace; end
end

# source://mini_racer//lib/mini_racer.rb#39
class MiniRacer::V8OutOfMemoryError < ::MiniRacer::EvalError; end

# source://mini_racer//lib/mini_racer/version.rb#4
MiniRacer::VERSION = T.let(T.unsafe(nil), String)
