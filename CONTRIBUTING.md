# Contributing

## Writing pull request descriptions

A PR description helps a reviewer understand the change, judge the decisions behind it, and know where to look. The diff and CI already cover the rest, so the description shouldn't repeat them.

[`.github/pull_request_template.md`](.github/pull_request_template.md) sets up these sections for you.

### Sections, in this order

#### 1. TL;DR

One or two sentences: what changes, and for whom. Write it so someone can stop reading here.

> PrusaLink printers can now be added from the UI: pick PrusaLink, enter the address and password, test the connection, save.

#### 2. Issue and scope

- `Closes #123` if the PR finishes the issue. `Part of #123` if it's one step of it.
- **The issue in two or three lines:** the problem and why it matters now. Don't paste the issue.
- **Scope:**
  - what this PR covers of the issue;
  - what it leaves out, and where that work goes (the next PR in the stack, or a follow-up issue).
- **For a stack:** list every PR in merge order, and mark this one with ← this PR.
- **No issue?** Say in one line why the PR exists.

#### 3. Architecture

Mermaid diagrams that show the structure of the change. Required when the PR adds or changes code paths. Skip it for docs-only or config-only PRs.

- **Dependency diagram:** a `flowchart` of who uses whom after this PR.
  - Group nodes by layer with `subgraph`s (UI, GraphQL, Models, Services, Gems).
  - Mark new nodes and changed nodes, and add a one-line legend under the diagram:
    ```
    classDef added fill:#dafbe1,stroke:#1a7f37,color:#1f2328
    classDef changed fill:#fff8c5,stroke:#9a6700,color:#1f2328
    ```
- **Call diagrams:** one `sequenceDiagram` per runtime flow the PR adds or changes. Never more than three.
  - Use the real method names.
  - Show the error and refusal paths with `alt`.
- **Rules for both:**
  - Draw only what exists in the code on the branch, not what's planned.
  - Keep each diagram to about 15 nodes or 6 participants. Split a bigger one.
  - Put one or two sentences under each diagram saying what to notice.
  - Render each diagram before posting, and look at the result. Mermaid fails silently on GitHub. `npx @mermaid-js/mermaid-cli -i diagram.mmd -o diagram.png` works locally.

#### 4. What it looks like

Show what's new whenever you can, so a reviewer doesn't have to run the branch to picture it. Pick whatever fits the change:

| Change | Show |
|---|---|
| UI | Screenshots, before and after when something existing changed. Include the empty, error and loading states the PR adds. |
| GraphQL | A sample query or mutation with its response, including an error response if the PR adds error codes. |
| Background work, logs, CLI | The log lines or output a person will actually see. |
| HTTP to printers or other services | The requests sent: method, path and the headers that matter. |
| Data | A sample record or Redis value, before and after a migration. |

- Use real output: capture it from the running app or a console session. If you construct an example from the code instead, label it "Example".
- Never paste secrets, API keys or real hostnames. Replace them with placeholders.
- Screenshots: drag them into the PR description on GitHub, which hosts them. Crop to the part that changed.
- Skip this section when nothing is visible: a pure refactor, for example. The Architecture diagrams already cover that.

#### 5. Decisions

Every choice a reviewer might question or want to revisit. Each one gets the decision, **why** it was made (and the alternative it beat), and its **impact**.

> - **Encryption keys are derived from `SECRET_KEY_BASE`.**
>   **Why:** self-hosters already set it, and a new environment variable would break existing installs.
>   **Impact:** rotating `SECRET_KEY_BASE` makes stored printer passwords unreadable. Docker installs must keep `storage/`.

Impact means what changes for users, deployers, data, performance or later work. "None" is a valid answer.

#### 6. Review focus

Where the reviewer's attention matters most, riskiest first.

- Name the file or method, and what to check: "the state mapping in `Printer::StateFamily.for_prusalink`: is `BUSY` really operational?"
- Include anything CI can't check: a manual or hardware test that wasn't done, a migration on production data, behaviour on a real printer.
- Say what's safe to skim: generated RBIs, `db/schema.rb`, lockfiles, cassettes.

### Leave out

- **Testing sections.** CI is the record of what passed. Anything CI can't check goes under Review focus as a risk.
- **Lists of changes or files.** The diff already shows them. Explain the intent in the TL;DR and the decisions instead.
- **The issue copied word for word**, background the reviewer doesn't need, or a recap at the end.

### Style

- Plain words, short sentences. Use the names that appear in the code.
- Aim for a read of about two minutes. The diagrams carry the structure, so the prose can stay short.
- Labels: one `type:`, the relevant `area:` labels, and `stack:` labels when they help split the work.
