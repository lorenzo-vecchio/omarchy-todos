.pragma library

// Small, dependency-free model helpers for the Todos plugin.
// The store is a plain JSON file owned by the user:
//   { "version": 1, "todos": [ ... ] }
// Every function returns fresh arrays/objects so QML bindings see changes.

var MAX_TODOS = 5000
var MAX_TAGS = 200
var MAX_TITLE = 200
var MAX_DESCRIPTION = 1000
var MAX_TAG = 40

function pad2(value) {
  return (value < 10 ? "0" : "") + value
}

function nowIso(now) {
  var date = now instanceof Date ? now : new Date()
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())
}

function isIsoDate(value) {
  var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(value || ""))
  if (!match) return false
  var year = Number(match[1])
  var month = Number(match[2])
  var day = Number(match[3])
  if (month < 1 || month > 12 || day < 1 || day > 31) return false
  var date = new Date(year, month - 1, day)
  return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day
}

function dateFromIso(value) {
  var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(value || ""))
  if (!match) return null
  return new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]))
}

function addDaysIso(days, fromIso) {
  var date = fromIso && isIsoDate(fromIso) ? dateFromIso(fromIso) : new Date()
  date.setDate(date.getDate() + Number(days || 0))
  return nowIso(date)
}

function cleanText(value, maxLength) {
  var text = String(value == null ? "" : value)
    .replace(/[\u0000-\u001f\u007f]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
  return text.slice(0, maxLength)
}

function cleanTag(value) {
  return cleanText(value, MAX_TAG).replace(/^#+/, "").trim()
}

function tagKey(value) {
  return cleanTag(value).toLowerCase()
}

function makeId() {
  return Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 9)
}

function newTodo(fields) {
  var source = fields || ({})
  return {
    id: makeId(),
    title: cleanText(source.title, MAX_TITLE),
    description: cleanText(source.description, MAX_DESCRIPTION),
    tag: cleanTag(source.tag),
    date: isIsoDate(source.date) ? String(source.date) : "",
    done: source.done === true,
    createdAt: typeof source.createdAt === "number" && isFinite(source.createdAt)
      ? source.createdAt
      : Date.now()
  }
}

function normalizeTodo(raw) {
  if (!raw || typeof raw !== "object") return null
  var title = cleanText(raw.title, MAX_TITLE)
  if (title === "") return null
  var id = typeof raw.id === "string" ? raw.id : ""
  if (!/^[A-Za-z0-9_-]{1,80}$/.test(id)) id = makeId()
  return {
    id: id,
    title: title,
    description: cleanText(raw.description, MAX_DESCRIPTION),
    tag: cleanTag(raw.tag),
    date: isIsoDate(raw.date) ? String(raw.date) : "",
    done: raw.done === true,
    createdAt: typeof raw.createdAt === "number" && isFinite(raw.createdAt)
      ? raw.createdAt
      : Date.now()
  }
}

function defaultTags() {
  return ["work", "personal"]
}

function normalizeTags(list) {
  var tags = []
  var seen = ({})
  if (!Array.isArray(list)) return tags
  for (var i = 0; i < list.length && tags.length < MAX_TAGS; i++) {
    var tag = cleanTag(list[i])
    var key = tagKey(tag)
    if (key === "" || seen[key]) continue
    seen[key] = true
    tags.push(tag)
  }
  return tags
}

// Tags used by todos, in first-seen order. Only needed to migrate a store
// written before tags became an explicit user-owned list.
function tagsOf(todos) {
  var seen = ({})
  var tags = []
  for (var i = 0; i < todos.length && tags.length < MAX_TAGS; i++) {
    var tag = cleanTag(todos[i].tag)
    var key = tagKey(tag)
    if (key === "" || seen[key]) continue
    seen[key] = true
    tags.push(tag)
  }
  return tags
}

function parseStore(raw) {
  var parsed = ({})
  try {
    parsed = JSON.parse(raw || "{}")
  } catch (error) {
    parsed = ({})
  }
  var list = parsed && Array.isArray(parsed.todos) ? parsed.todos : []
  var todos = []
  for (var i = 0; i < list.length && i < MAX_TODOS; i++) {
    var todo = normalizeTodo(list[i])
    if (todo) todos.push(todo)
  }

  var tags
  if (parsed && Array.isArray(parsed.tags)) {
    tags = normalizeTags(parsed.tags)
  } else {
    // A store from before explicit tags: keep the starter tags and adopt
    // whatever tags its todos already carry.
    tags = normalizeTags(defaultTags().concat(tagsOf(todos)))
  }
  return { todos: todos, tags: tags }
}

function serialize(todos, tags) {
  return JSON.stringify({
    version: 2,
    tags: normalizeTags(tags || []),
    todos: todos || []
  }, null, 2) + "\n"
}

function cloneWith(todo, changes) {
  var next = {
    id: todo.id,
    title: todo.title,
    description: todo.description,
    tag: todo.tag,
    date: todo.date,
    done: todo.done,
    createdAt: todo.createdAt
  }
  for (var key in changes) next[key] = changes[key]
  return next
}

function hasTodo(todos, id) {
  for (var i = 0; i < todos.length; i++) if (todos[i].id === id) return true
  return false
}

function hasTag(todos, tag) {
  var key = tagKey(tag)
  if (key === "") return false
  for (var i = 0; i < todos.length; i++) if (tagKey(todos[i].tag) === key) return true
  return false
}

function openCount(todos) {
  var count = 0
  for (var i = 0; i < todos.length; i++) if (!todos[i].done) count++
  return count
}

function dueTodayCount(todos, today) {
  var count = 0
  for (var i = 0; i < todos.length; i++) {
    if (!todos[i].done && todos[i].date === today) count++
  }
  return count
}

function hasTagEntry(tags, tag) {
  var key = tagKey(tag)
  if (key === "") return false
  for (var i = 0; i < tags.length; i++) if (tagKey(tags[i]) === key) return true
  return false
}

function doneCount(todos) {
  var count = 0
  for (var i = 0; i < todos.length; i++) if (todos[i].done) count++
  return count
}

function tagIndex(tag) {
  var key = tagKey(tag)
  var hash = 0
  for (var i = 0; i < key.length; i++) {
    hash = ((hash << 5) - hash + key.charCodeAt(i)) | 0
  }
  return Math.abs(hash)
}

function compareTodos(a, b) {
  if (a.done !== b.done) return a.done ? 1 : -1
  var left = a.date === "" ? "9999-12-31" : a.date
  var right = b.date === "" ? "9999-12-31" : b.date
  if (left !== right) return left < right ? -1 : 1
  if (a.createdAt !== b.createdAt) return a.createdAt < b.createdAt ? -1 : 1
  var leftTitle = a.title.toLowerCase()
  var rightTitle = b.title.toLowerCase()
  return leftTitle < rightTitle ? -1 : (leftTitle > rightTitle ? 1 : 0)
}

// "Due today" is a pinned group of open todos. "All todos" carries everything
// else, so a todo never appears twice. The tag filter applies to both groups.
// When doneOnly is set, the whole list is the completed todos (still filtered
// by tag if one is active), and the today group stays empty.
function organize(todos, tagFilter, today, doneOnly) {
  var key = tagKey(tagFilter)
  var dueToday = []
  var rest = []
  for (var i = 0; i < todos.length; i++) {
    var todo = todos[i]
    if (key !== "" && tagKey(todo.tag) !== key) continue
    if (doneOnly) {
      if (todo.done) rest.push(todo)
    } else if (!todo.done && todo.date === today) {
      dueToday.push(todo)
    } else {
      rest.push(todo)
    }
  }
  dueToday.sort(compareTodos)
  rest.sort(compareTodos)
  return { today: dueToday, all: rest }
}
