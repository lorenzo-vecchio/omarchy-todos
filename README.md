# Todos

A small todo list for the Omarchy bar.

- A todo is just a title by default.
- Optionally give it a due date, a description, and a tag.
- Todos due today are pinned in their own section above the rest of the list.
- Completed todos sink to the bottom of the list in a dimmed, struck-through style.
- Filter by tag, or use **Done** to see only completed todos.
- **Clear done** deletes every completed todo in one click.
- Tags are yours: create them, give them a name, and delete them. Omarchy
  starts with `work` and `personal`. Colors are assigned automatically and stay
  stable for a given name.
- The bar icon shows the number of open todos. Right-click it (or use the
  button in the panel header) to count only todos due today instead.

Everything is local. There are no accounts, network requests, or background
services.

## Install

```sh
omarchy plugin add https://github.com/lorenzo-vecchio/omarchy-todos.git --enable
```

Omarchy's plugin command copies the repository into
`~/.config/omarchy/plugins/io.github.lorenzo-vecchio.todos` and reloads the
shell.

## Usage

- Click the checklist icon in the bar to open the panel.
- Type a title and press Enter to add a todo with nothing else attached.
- Press **Details** to add an optional date (`YYYY-MM-DD`, with Today and
  Tomorrow shortcuts), a description, and a tag.
- Click a todo row to edit it. Click the checkbox to mark it done; completed
  todos move to the end of the list in a dimmed, struck-through style.
- Hover a row and click the close icon to delete it.
- Click a tag chip to filter; click **All** to clear the filter. Click **Done**
  to list only completed todos.
- Click **Clear done (n)** to delete every completed todo.
- Click **Tags** to open the tag manager. Add a tag with the **New tag** field;
  click the `×` beside a tag to delete it. Deleting a tag also clears it from
  every todo that used it. Typing a new tag on a todo adds it to your tags.
- Escape closes the panel. When a field is focused, Escape first leaves the
  edit form, the tag manager, or the optional details.
- Right-click the bar icon to switch its count between all open todos and
  todos due today. The panel header has the same switch.

The panel is also available over IPC:

```sh
omarchy-shell io.github.lorenzo-vecchio.todos toggle
omarchy-shell io.github.lorenzo-vecchio.todos open
omarchy-shell io.github.lorenzo-vecchio.todos close
```

## Configure

The bar count mode is stored on the widget's entry in
`~/.config/omarchy/shell.json`:

```sh
# Count every open todo (the default)
omarchy bar set io.github.lorenzo-vecchio.todos countMode total

# Count only todos due today
omarchy bar set io.github.lorenzo-vecchio.todos countMode due
```

If the widget is not in the layout, the choice lasts for the current session
only.

## Data

Todos and tags are stored as JSON at:

```
~/.local/state/omarchy/todos.json
```

The file is created on the first save. It is plain JSON and safe to back up or
edit while the shell is running; changes are picked up automatically. The
format is:

```json
{
  "version": 2,
  "tags": ["work", "personal", "errands"],
  "todos": [
    {
      "id": "lk3j2h-8f2a1c",
      "title": "Buy milk",
      "description": "",
      "tag": "errands",
      "date": "2026-11-12",
      "done": false,
      "createdAt": 1762900000000
    }
  ]
}
```

Only the title is required; `description`, `tag`, and `date` may be empty
strings, and old or hand-edited entries are normalized on load. A store from an
earlier version without a `tags` list is migrated by keeping `work`, `personal`,
and any tags its todos already use.

## Remove

```sh
omarchy plugin disable io.github.lorenzo-vecchio.todos
omarchy plugin remove io.github.lorenzo-vecchio.todos --yes
```

Removing the plugin does not delete `~/.local/state/omarchy/todos.json`.
Delete that file yourself if you also want to remove the data.

## Requirements

- Omarchy with the Quickshell-based shell (Omarchy Quattro or newer)
- No extra packages, Python, or external services

## License

MIT
