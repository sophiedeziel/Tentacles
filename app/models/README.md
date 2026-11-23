# Models

All the domain logic lives here. There is no `app/services`: a service object is a model whose `save` does the work.
GraphQL mutations, jobs and the spooler find records, build a model and save it. They hold no domain logic.

## Two base classes

| Base | For |
|---|---|
| `ApplicationRecord` | Database tables (`Printer`, `Printer::Job`, `Dashboard::Section`, `Library::Item`) |
| `ApplicationModel` | Everything else: commands, records kept in Redis, objects that talk to a printer |

`ApplicationModel` includes `ActiveModel::Model` and `ActiveModel::Attributes`, and adds ActiveRecord's persistence
API: `save` / `save!`, `update` / `update!`, `create` / `create!`, `readonly?`. See its doc comment.

## Domains

Code is grouped by domain namespace, not by kind (no `Services::`, `Stores::` or `Adapters::`):

| Namespace | What |
|---|---|
| `Printer` | The record, and everything about one printer: `Printer::Status`, `Printer::Backend`, `Printer::Monitor`, the commands (`Printer::Pause`, `Printer::Addition`, ...) |
| `Dashboard` | Sections and widgets (`table_name_prefix 'dashboard_'`) |
| `Library` | The files and their labels, whatever their format |
| `Gcode` | Reading G-code: `Gcode::Analysis`, `Gcode::Slicer` |

A new concept goes under the domain it belongs to, as a noun. Start a new top-level namespace only for a new domain.
When the record is also the domain (`Printer`), nest under the record. Otherwise the domain is a plain module.

- Don't name a constant after a core class inside a namespace (`Library::File` would hide `::File` in `Library`).
- Don't nest a class under a name that an association resolves to: `Dashboard::Widget::Printer` would hide `::Printer`
  from the widget's `belongs_to :printer`.
- Outside `app/models` (GraphQL types, mutations, `lib/`), write `::Printer`: inside `module Types`, `Printer` is
  `Types::Printer`.
- Renaming a class stored in the database (STI `type`, polymorphic `*_type`, Active Storage `record_type`) needs a data
  migration. Tables keep their names (`self.table_name`).

## Commands

A command is a noun: `Printer::Removal`, not `Printers::Remove` or `RemovePrinterService`. Its inputs are attributes,
its checks are validations, and the work is a private `#persist`:

```ruby
class Printer
  class Upload < ApplicationModel
    attribute :printer
    attribute :path, :string
    attribute :print, :boolean, default: false

    validates :printer, :path, presence: true

    private

    def persist
      printer.api.upload(path, print: self.print) # self: not Kernel#print
    end
  end
end

Printer::Upload.new(printer:, path:).save!
```

- **`save` or `save!`?** Use `save` when the caller shows the error to the user: it returns false with `errors` filled.
  Use `save!` when a failure must raise (an upload, a background job).
- **Expected failures** (the printer is unreachable, the credentials are wrong) are declared with
  `rescue_into_errors Printer::Backend::Error`. `save` then puts their message in `errors[:base]` and returns false.
  Every other error still raises: bugs are never swallowed. Override the private `#error_message_for(error)` to word
  or redact the message.
- **Refusals are validations.** A command that's not allowed in the current state adds an error to `:base` with the
  message shown to the user (see `Printer::Command`).
- **Results** a command produces are readable on it after `save` (`scan.ips`, `request.app_token`).
- **No `.call`.** Not on new models either.

## No callbacks

Don't use `before_*` / `after_*` callbacks or `skip_callback`, on `ApplicationModel` or `ApplicationRecord`. `#persist`
runs every step of a save inline, in order: the write, then its follow-ups (pushes, spooler notifications, cleanup).

```ruby
def persist
  destroy_printer
  forget_redis_keys
  stop_spool
  push_print_queue_changed
end
```

- A best-effort follow-up rescues and logs its own errors, so the next steps still run (see `Printer::Removal`).
- A shared sequence goes in the base class's `#persist` (`Printer::Command#persist` sends the command, then refreshes
  the status).
- Whoever writes a record also sends its push: `job.update(status:)` is followed by `job.push_print_queue_changed`.
- `dependent:` on associations is fine.

## Records that aren't tables

Records kept elsewhere (Redis, a printer's API) use ActiveRecord's vocabulary, not `read` / `write` / `fetch`:

| Method | Example |
|---|---|
| `.find_by`, `.find` | `Printer::Status.find_by(printer_id:)`, `Printer::AppKeyRequest.find(id)` |
| `.where` | `Printer::Status.where(printer_id: ids)`: one Redis `MGET`, missing ones left out |
| `.last`, `.exists?` | `NetworkScan.last`, `Printer::Disconnection.exists?(printer_id:)` |
| `.find_or_create_by` | `Printer::ApiCache.find_or_create_by(printer_id:, api_method:, expires_in:) { api.version }` |
| `.delete_by` | `Printer::Status.delete_by(printer_id:)` |
| `#save`, `#save!` | Write it: `status.save!` stores the snapshot and pushes `printerStatusChanged` |
| `#reload` | Read it again from its source: `status.reload` polls the printer |
| `#readonly?` | True for what can't be written (`Printer::LiveJob`): `save` raises `ApplicationModel::ReadOnlyRecord` |

Keep the Redis key formats when changing these models: running processes and stored data use them.

## Attributes

- Primitives get a type: `attribute :interval, :float, default: 5.0`.
- Objects stay untyped: `attribute :printer`.
- `ApplicationModel::EnumType`, `ModelType`, `TimeType` and `ArrayType` cast T::Enums, nested models, times and arrays
  (see `Printer::Status`). `validates :hotend, nested: true` validates a nested model with its own validations.
- Integers serialized to JSON are `:big_integer`: `:integer` raises `ActiveModel::RangeError` from 2³¹.
- State that isn't an input (threads, memoized reads) stays in instance variables.
- Mixins are `ActiveSupport::Concern`s (`Printer::Monitor::Runnable`).
- Value lists shared by two sides (a Redis message, a stored value) are a `T::Enum`: `Printer::StateFamily`,
  `Printer::SpoolerCommand`.

## Printer backends

`Printer::Backend` is the base of the API adapters (`Printer::Backend::Octoprint`, `::Prusalink`), and
`Printer::Backend::ADAPTERS` lists them. To add a backend:

1. Add its adapter under `Printer::Backend`, implementing the abstract methods.
2. Add its monitor reader under `Printer::Monitor`, and return it from the adapter's `reader_class`.
3. Add one entry to `ADAPTERS`. `Printer::BACKENDS`, `Printer::Backend.for` and `Printer::Monitor::Reader.for` read
   it.

Code that is specific to one backend but runs without a printer goes under its adapter's namespace without
inheriting it (`Printer::Backend::Octoprint::AppKey`).

## Sorbet

New files are `# typed: strict` when possible, `# typed: true` otherwise. After adding or changing attributes, run
`bin/tapioca dsl <Constant>` for the constants you changed. Don't run it for everything: it rewrites unrelated RBIs.

Signatures are inline RBS comments, not `sig` blocks, and are checked statically only (no runtime checks):

```ruby
# The adapter of the printer's backend
#: (Printer printer) -> Printer::Backend
def for(printer)

@live_job ||= LiveJob.find_by(printer:) #: LiveJob?   # instead of T.let
#: self as Printer                                     # instead of T.bind
```

- Abstract methods get `# @abstract` above their signature and a forwarding `super` as their body (Sorbet requires it):
  `def send_command = super`. Modules with only abstract methods are `# @interface`.
- An abstract model gets `# @abstract` above its class, so Sorbet refuses `.new` on it, and `self.abstract_class = true`
  (like ActiveRecord) so it raises at runtime too (`Printer::Command`, `Printer::Backend`).
- No `extend T::Sig` / `T::Helpers`. `T::Enum`, `T::Struct`, `T.must` and the generated RBIs in `sorbet/rbi` stay.

## Specs

`spec/models` mirrors `app/models`. Test a command through `save` / `save!` and its `errors`, not through `#persist`.
In a fresh checkout or worktree, run `bin/worktree-setup` first: without `node_modules`, `spec/requests/home_spec.rb`
fails with a 500.
