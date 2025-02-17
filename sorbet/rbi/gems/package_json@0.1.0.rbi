# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `package_json` gem.
# Please instead update this file by running `bin/tapioca gem package_json`.


# source://package_json//lib/package_json/managers/base.rb#1
class PackageJson
  # @return [PackageJson] a new instance of PackageJson
  #
  # source://package_json//lib/package_json.rb#31
  def initialize(path_to_directory = T.unsafe(nil), fallback_manager: T.unsafe(nil)); end

  # source://package_json//lib/package_json.rb#59
  def delete!(key); end

  # Returns the value of attribute directory.
  #
  # source://package_json//lib/package_json.rb#17
  def directory; end

  # source://package_json//lib/package_json.rb#42
  def fetch(key, default = T.unsafe(nil)); end

  # Returns the value of attribute manager.
  #
  # source://package_json//lib/package_json.rb#17
  def manager; end

  # Merges the hash returned by the passed block into the existing content of the `package.json`
  #
  # source://package_json//lib/package_json.rb#53
  def merge!; end

  # source://package_json//lib/package_json.rb#69
  def record_package_manager!; end

  private

  # source://package_json//lib/package_json.rb#75
  def determine_package_manager(fallback_manager); end

  # source://package_json//lib/package_json.rb#113
  def ensure_package_json_exists; end

  # source://package_json//lib/package_json.rb#92
  def new_package_manager(package_manager_name); end

  # source://package_json//lib/package_json.rb#109
  def package_json_path; end

  # source://package_json//lib/package_json.rb#121
  def read_package_json; end

  # source://package_json//lib/package_json.rb#125
  def write_package_json(contents); end

  class << self
    # source://package_json//lib/package_json.rb#19
    def fetch_default_fallback_manager; end

    # source://package_json//lib/package_json.rb#23
    def read(path_to_directory = T.unsafe(nil), fallback_manager: T.unsafe(nil)); end
  end
end

# source://package_json//lib/package_json.rb#13
class PackageJson::Error < ::StandardError; end

# source://package_json//lib/package_json/managers/base.rb#2
module PackageJson::Managers; end

# source://package_json//lib/package_json/managers/base.rb#3
class PackageJson::Managers::Base
  # @return [Base] a new instance of Base
  #
  # source://package_json//lib/package_json/managers/base.rb#7
  def initialize(package_json, binary_name:); end

  # Adds the given packages
  #
  # @raise [NotImplementedError]
  #
  # source://package_json//lib/package_json/managers/base.rb#43
  def add(packages, type: T.unsafe(nil)); end

  # Adds the given packages
  #
  # source://package_json//lib/package_json/managers/base.rb#48
  def add!(packages, type: T.unsafe(nil)); end

  # @return [String] the binary to invoke for running the package manager
  #
  # source://package_json//lib/package_json/managers/base.rb#5
  def binary; end

  # Installs the dependencies specified in the `package.json` file
  #
  # @raise [NotImplementedError]
  #
  # source://package_json//lib/package_json/managers/base.rb#28
  def install(frozen: T.unsafe(nil)); end

  # Installs the dependencies specified in the `package.json` file
  #
  # source://package_json//lib/package_json/managers/base.rb#38
  def install!(frozen: T.unsafe(nil)); end

  # Provides the "native" command for executing a package with args for embedding into shell scripts
  #
  # @raise [NotImplementedError]
  #
  # source://package_json//lib/package_json/managers/base.rb#96
  def native_exec_command(script_name, args = T.unsafe(nil)); end

  # Provides the "native" command for installing dependencies with this package manager for embedding into scripts
  #
  # @raise [NotImplementedError]
  #
  # source://package_json//lib/package_json/managers/base.rb#33
  def native_install_command(frozen: T.unsafe(nil)); end

  # Provides the "native" command for running the script with args for embedding into shell scripts
  #
  # @raise [NotImplementedError]
  #
  # source://package_json//lib/package_json/managers/base.rb#87
  def native_run_command(script_name, args = T.unsafe(nil), silent: T.unsafe(nil)); end

  # Removes the given packages
  #
  # @raise [NotImplementedError]
  #
  # source://package_json//lib/package_json/managers/base.rb#53
  def remove(packages); end

  # Removes the given packages
  #
  # source://package_json//lib/package_json/managers/base.rb#58
  def remove!(packages); end

  # Runs the script assuming it is defined in the `package.json` file
  #
  # @raise [NotImplementedError]
  #
  # source://package_json//lib/package_json/managers/base.rb#65
  def run(script_name, args = T.unsafe(nil), silent: T.unsafe(nil)); end

  # Runs the script assuming it is defined in the `package.json` file
  #
  # source://package_json//lib/package_json/managers/base.rb#74
  def run!(script_name, args = T.unsafe(nil), silent: T.unsafe(nil)); end

  # source://package_json//lib/package_json/managers/base.rb#14
  def version; end

  private

  # source://package_json//lib/package_json/managers/base.rb#109
  def build_full_cmd(sub_cmd, args); end

  # @raise [Error]
  #
  # source://package_json//lib/package_json/managers/base.rb#105
  def raise_exited_with_non_zero_code_error; end

  # source://package_json//lib/package_json/managers/base.rb#113
  def raw(sub_cmd, args); end
end

# source://package_json//lib/package_json/managers/bun_like.rb#3
class PackageJson::Managers::BunLike < ::PackageJson::Managers::Base
  # @return [BunLike] a new instance of BunLike
  #
  # source://package_json//lib/package_json/managers/bun_like.rb#4
  def initialize(package_json); end

  # Adds the given packages
  #
  # source://package_json//lib/package_json/managers/bun_like.rb#19
  def add(packages, type: T.unsafe(nil)); end

  # Installs the dependencies specified in the `package.json` file
  #
  # source://package_json//lib/package_json/managers/bun_like.rb#9
  def install(frozen: T.unsafe(nil)); end

  # source://package_json//lib/package_json/managers/bun_like.rb#46
  def native_exec_command(script_name, args = T.unsafe(nil)); end

  # Provides the "native" command for installing dependencies with this package manager for embedding into scripts
  #
  # source://package_json//lib/package_json/managers/bun_like.rb#14
  def native_install_command(frozen: T.unsafe(nil)); end

  # Provides the "native" command for running the script with args for embedding into shell scripts
  #
  # source://package_json//lib/package_json/managers/bun_like.rb#38
  def native_run_command(script_name, args = T.unsafe(nil), silent: T.unsafe(nil)); end

  # Removes the given packages
  #
  # source://package_json//lib/package_json/managers/bun_like.rb#24
  def remove(packages); end

  # Runs the script assuming it is defined in the `package.json` file
  #
  # source://package_json//lib/package_json/managers/bun_like.rb#29
  def run(script_name, args = T.unsafe(nil), silent: T.unsafe(nil)); end

  private

  # source://package_json//lib/package_json/managers/bun_like.rb#55
  def build_run_args(script_name, args, _silent:); end

  # source://package_json//lib/package_json/managers/bun_like.rb#65
  def package_type_install_flag(type); end

  # source://package_json//lib/package_json/managers/bun_like.rb#59
  def with_frozen_flag(frozen); end
end

# source://package_json//lib/package_json/managers/npm_like.rb#3
class PackageJson::Managers::NpmLike < ::PackageJson::Managers::Base
  # @return [NpmLike] a new instance of NpmLike
  #
  # source://package_json//lib/package_json/managers/npm_like.rb#4
  def initialize(package_json); end

  # Adds the given packages
  #
  # source://package_json//lib/package_json/managers/npm_like.rb#25
  def add(packages, type: T.unsafe(nil)); end

  # Installs the dependencies specified in the `package.json` file
  #
  # source://package_json//lib/package_json/managers/npm_like.rb#9
  def install(frozen: T.unsafe(nil)); end

  # source://package_json//lib/package_json/managers/npm_like.rb#52
  def native_exec_command(script_name, args = T.unsafe(nil)); end

  # Provides the "native" command for installing dependencies with this package manager for embedding into scripts
  #
  # source://package_json//lib/package_json/managers/npm_like.rb#17
  def native_install_command(frozen: T.unsafe(nil)); end

  # Provides the "native" command for running the script with args for embedding into shell scripts
  #
  # source://package_json//lib/package_json/managers/npm_like.rb#44
  def native_run_command(script_name, args = T.unsafe(nil), silent: T.unsafe(nil)); end

  # Removes the given packages
  #
  # source://package_json//lib/package_json/managers/npm_like.rb#30
  def remove(packages); end

  # Runs the script assuming it is defined in the `package.json` file
  #
  # source://package_json//lib/package_json/managers/npm_like.rb#35
  def run(script_name, args = T.unsafe(nil), silent: T.unsafe(nil)); end

  private

  # source://package_json//lib/package_json/managers/npm_like.rb#61
  def build_run_args(script_name, args, silent:); end

  # source://package_json//lib/package_json/managers/npm_like.rb#69
  def package_type_install_flag(type); end
end

# source://package_json//lib/package_json/managers/pnpm_like.rb#3
class PackageJson::Managers::PnpmLike < ::PackageJson::Managers::Base
  # @return [PnpmLike] a new instance of PnpmLike
  #
  # source://package_json//lib/package_json/managers/pnpm_like.rb#4
  def initialize(package_json); end

  # Adds the given packages
  #
  # source://package_json//lib/package_json/managers/pnpm_like.rb#19
  def add(packages, type: T.unsafe(nil)); end

  # Installs the dependencies specified in the `package.json` file
  #
  # source://package_json//lib/package_json/managers/pnpm_like.rb#9
  def install(frozen: T.unsafe(nil)); end

  # source://package_json//lib/package_json/managers/pnpm_like.rb#46
  def native_exec_command(script_name, args = T.unsafe(nil)); end

  # Provides the "native" command for installing dependencies with this package manager for embedding into scripts
  #
  # source://package_json//lib/package_json/managers/pnpm_like.rb#14
  def native_install_command(frozen: T.unsafe(nil)); end

  # Provides the "native" command for running the script with args for embedding into shell scripts
  #
  # source://package_json//lib/package_json/managers/pnpm_like.rb#38
  def native_run_command(script_name, args = T.unsafe(nil), silent: T.unsafe(nil)); end

  # Removes the given packages
  #
  # source://package_json//lib/package_json/managers/pnpm_like.rb#24
  def remove(packages); end

  # Runs the script assuming it is defined in the `package.json` file
  #
  # source://package_json//lib/package_json/managers/pnpm_like.rb#29
  def run(script_name, args = T.unsafe(nil), silent: T.unsafe(nil)); end

  private

  # source://package_json//lib/package_json/managers/pnpm_like.rb#55
  def build_run_args(script_name, args, silent:); end

  # source://package_json//lib/package_json/managers/pnpm_like.rb#70
  def package_type_install_flag(type); end

  # source://package_json//lib/package_json/managers/pnpm_like.rb#62
  def with_frozen_flag(frozen); end
end

# source://package_json//lib/package_json/managers/yarn_berry_like.rb#3
class PackageJson::Managers::YarnBerryLike < ::PackageJson::Managers::Base
  # @return [YarnBerryLike] a new instance of YarnBerryLike
  #
  # source://package_json//lib/package_json/managers/yarn_berry_like.rb#4
  def initialize(package_json); end

  # Adds the given packages
  #
  # source://package_json//lib/package_json/managers/yarn_berry_like.rb#19
  def add(packages, type: T.unsafe(nil)); end

  # Installs the dependencies specified in the `package.json` file
  #
  # source://package_json//lib/package_json/managers/yarn_berry_like.rb#9
  def install(frozen: T.unsafe(nil)); end

  # source://package_json//lib/package_json/managers/yarn_berry_like.rb#46
  def native_exec_command(script_name, args = T.unsafe(nil)); end

  # Provides the "native" command for installing dependencies with this package manager for embedding into scripts
  #
  # source://package_json//lib/package_json/managers/yarn_berry_like.rb#14
  def native_install_command(frozen: T.unsafe(nil)); end

  # Provides the "native" command for running the script with args for embedding into shell scripts
  #
  # source://package_json//lib/package_json/managers/yarn_berry_like.rb#38
  def native_run_command(script_name, args = T.unsafe(nil), silent: T.unsafe(nil)); end

  # Removes the given packages
  #
  # source://package_json//lib/package_json/managers/yarn_berry_like.rb#24
  def remove(packages); end

  # Runs the script assuming it is defined in the `package.json` file
  #
  # source://package_json//lib/package_json/managers/yarn_berry_like.rb#29
  def run(script_name, args = T.unsafe(nil), silent: T.unsafe(nil)); end

  private

  # source://package_json//lib/package_json/managers/yarn_berry_like.rb#55
  def build_run_args(script_name, args, _silent:); end

  # source://package_json//lib/package_json/managers/yarn_berry_like.rb#67
  def package_type_install_flag(type); end

  # source://package_json//lib/package_json/managers/yarn_berry_like.rb#59
  def with_frozen_flag(frozen); end
end

# source://package_json//lib/package_json/managers/yarn_classic_like.rb#3
class PackageJson::Managers::YarnClassicLike < ::PackageJson::Managers::Base
  # @return [YarnClassicLike] a new instance of YarnClassicLike
  #
  # source://package_json//lib/package_json/managers/yarn_classic_like.rb#4
  def initialize(package_json); end

  # Adds the given packages
  #
  # source://package_json//lib/package_json/managers/yarn_classic_like.rb#19
  def add(packages, type: T.unsafe(nil)); end

  # Installs the dependencies specified in the `package.json` file
  #
  # source://package_json//lib/package_json/managers/yarn_classic_like.rb#9
  def install(frozen: T.unsafe(nil)); end

  # source://package_json//lib/package_json/managers/yarn_classic_like.rb#46
  def native_exec_command(script_name, args = T.unsafe(nil)); end

  # Provides the "native" command for installing dependencies with this package manager for embedding into scripts
  #
  # source://package_json//lib/package_json/managers/yarn_classic_like.rb#14
  def native_install_command(frozen: T.unsafe(nil)); end

  # Provides the "native" command for running the script with args for embedding into shell scripts
  #
  # source://package_json//lib/package_json/managers/yarn_classic_like.rb#38
  def native_run_command(script_name, args = T.unsafe(nil), silent: T.unsafe(nil)); end

  # Removes the given packages
  #
  # source://package_json//lib/package_json/managers/yarn_classic_like.rb#24
  def remove(packages); end

  # Runs the script assuming it is defined in the `package.json` file
  #
  # source://package_json//lib/package_json/managers/yarn_classic_like.rb#29
  def run(script_name, args = T.unsafe(nil), silent: T.unsafe(nil)); end

  private

  # source://package_json//lib/package_json/managers/yarn_classic_like.rb#68
  def build_run_args(script_name, args, silent:); end

  # source://package_json//lib/package_json/managers/yarn_classic_like.rb#55
  def fetch_bin_path; end

  # source://package_json//lib/package_json/managers/yarn_classic_like.rb#81
  def package_type_install_flag(type); end

  # source://package_json//lib/package_json/managers/yarn_classic_like.rb#75
  def with_frozen_flag(frozen); end
end

# source://package_json//lib/package_json.rb#15
class PackageJson::NotImplementedError < ::PackageJson::Error; end

# source://package_json//lib/package_json/version.rb#4
PackageJson::VERSION = T.let(T.unsafe(nil), String)
