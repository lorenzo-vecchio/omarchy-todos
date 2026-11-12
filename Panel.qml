import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.lorenzo-vecchio.todos"
  ipcTarget: moduleName

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string stateDir: (Quickshell.env("HOME") || "") + "/.local/state/omarchy"
  readonly property string storePath: root.stateDir + "/todos.json"

  property var todos: []
  property var tags: []
  property string tagFilter: ""
  property bool doneOnly: false
  property bool tagsOpen: false
  property string pendingTagDelete: ""
  property bool detailsOpen: false
  property string editingId: ""
  property bool addDateInvalid: false
  property bool editDateInvalid: false
  property int clockTick: 0

  readonly property string today: {
    var _ = root.clockTick
    return Model.nowIso()
  }
  readonly property string tomorrow: Model.addDaysIso(1, root.today)

  readonly property var sections: Model.organize(root.todos, root.tagFilter, root.today, root.doneOnly)
  readonly property var todayTodos: sections.today
  readonly property var otherTodos: sections.all

  readonly property int openCount: Model.openCount(root.todos)
  readonly property int dueCount: Model.dueTodayCount(root.todos, root.today)
  readonly property int doneCount: Model.doneCount(root.todos)
  readonly property string countMode: String(root.setting("countMode", "total")) === "due" ? "due" : "total"
  readonly property int barCount: root.countMode === "due" ? root.dueCount : root.openCount
  readonly property string barTooltip: root.countMode === "due"
    ? strings.t("bar.tooltipDue").arg(Commons.I18n.formatNumber(root.barCount))
    : strings.t("bar.tooltip").arg(Commons.I18n.formatNumber(root.barCount))

  readonly property var editingTodo: {
    for (var i = 0; i < root.todos.length; i++) {
      if (root.todos[i].id === root.editingId) return root.todos[i]
    }
    return null
  }

  readonly property var tagHues: [0.02, 0.09, 0.14, 0.33, 0.49, 0.58, 0.72, 0.88]
  readonly property bool lightBackground: (0.2126 * Color.background.r + 0.7152 * Color.background.g + 0.0722 * Color.background.b) > 0.5

  function tagColor(tag) {
    var hue = root.tagHues[Model.tagIndex(tag) % root.tagHues.length]
    return Qt.hsva(hue, root.lightBackground ? 0.64 : 0.55, root.lightBackground ? 0.5 : 0.94, 1)
  }

  function tagTint(tag, alpha) {
    var color = root.tagColor(tag)
    return Qt.rgba(color.r, color.g, color.b, alpha)
  }

  function dateLabel(iso) {
    if (!iso) return ""
    if (iso === root.today) return strings.t("date.today")
    if (iso === root.tomorrow) return strings.t("date.tomorrow")
    var date = Model.dateFromIso(iso)
    if (!date) return iso
    return date.toLocaleDateString(Qt.locale(Commons.I18n.formatLocale), "d MMM")
  }

  function isOverdue(iso, done) {
    return !!iso && !done && iso < root.today
  }

  function persist(nextTodos, nextTags) {
    root.todos = nextTodos === undefined ? root.todos : nextTodos
    root.tags = nextTags === undefined ? root.tags : nextTags
    storeFile.setText(Model.serialize(root.todos, root.tags))
  }

  function loadStore(raw) {
    var parsed = Model.parseStore(raw)
    root.todos = parsed.todos
    root.tags = parsed.tags
    if (root.tagFilter !== "" && !Model.hasTagEntry(root.tags, root.tagFilter)) root.tagFilter = ""
    if (root.pendingTagDelete !== "" && !Model.hasTagEntry(root.tags, root.pendingTagDelete)) root.pendingTagDelete = ""
    if (root.editingId !== "" && !Model.hasTodo(root.todos, root.editingId)) root.editingId = ""
  }

  function withTag(tags, tag) {
    var clean = Model.cleanTag(tag)
    if (clean === "" || Model.hasTagEntry(tags, clean)) return tags
    return tags.concat([clean])
  }

  function setTagFilter(tag) {
    root.doneOnly = false
    root.tagFilter = tag
  }

  function setDoneFilter() {
    root.tagFilter = ""
    root.doneOnly = true
  }

  function clearFilters() {
    root.tagFilter = ""
    root.doneOnly = false
  }

  function addTodo() {
    var title = Model.cleanText(addTitle.text, Model.MAX_TITLE)
    if (title === "") {
      addTitle.forceActiveFocus()
      return
    }
    var date = String(addDate.text || "").trim()
    if (date !== "" && !Model.isIsoDate(date)) {
      root.addDateInvalid = true
      addDate.forceActiveFocus()
      return
    }

    var tag = Model.cleanTag(addTag.text) || Model.cleanTag(root.tagFilter)
    var next = root.todos.slice()
    next.push(Model.newTodo({
      title: title,
      description: addDesc.text,
      tag: tag,
      date: date
    }))
    root.persist(next, root.withTag(root.tags, tag))

    addTitle.text = ""
    addDate.text = ""
    addTag.text = ""
    addDesc.text = ""
    root.addDateInvalid = false
    root.detailsOpen = false
    root.clearFilters()
    root.editingId = ""
    Qt.callLater(function() { addTitle.forceActiveFocus() })
  }

  function beginEdit(todo) {
    if (!todo) return
    root.editingId = todo.id
    root.editDateInvalid = false
    editTitle.text = todo.title
    editDate.text = todo.date
    editTag.text = todo.tag
    editDesc.text = todo.description
    Qt.callLater(function() { editTitle.forceActiveFocus() })
  }

  function cancelEdit() {
    root.editingId = ""
    root.editDateInvalid = false
  }

  function saveEdit() {
    var todo = root.editingTodo
    if (!todo) {
      root.cancelEdit()
      return
    }
    var title = Model.cleanText(editTitle.text, Model.MAX_TITLE)
    if (title === "") {
      editTitle.forceActiveFocus()
      return
    }
    var date = String(editDate.text || "").trim()
    if (date !== "" && !Model.isIsoDate(date)) {
      root.editDateInvalid = true
      editDate.forceActiveFocus()
      return
    }

    var tag = Model.cleanTag(editTag.text)
    var next = []
    for (var i = 0; i < root.todos.length; i++) {
      if (root.todos[i].id === todo.id) {
        next.push(Model.cloneWith(root.todos[i], {
          title: title,
          date: date,
          description: Model.cleanText(editDesc.text, Model.MAX_DESCRIPTION),
          tag: tag
        }))
      } else {
        next.push(root.todos[i])
      }
    }
    root.persist(next, root.withTag(root.tags, tag))
    root.cancelEdit()
  }

  function toggleTodo(id) {
    var next = []
    for (var i = 0; i < root.todos.length; i++) {
      if (root.todos[i].id === id) {
        next.push(Model.cloneWith(root.todos[i], { done: !root.todos[i].done }))
      } else {
        next.push(root.todos[i])
      }
    }
    root.persist(next)
  }

  function deleteTodo(id) {
    var next = []
    for (var i = 0; i < root.todos.length; i++) {
      if (root.todos[i].id !== id) next.push(root.todos[i])
    }
    root.persist(next)
    if (root.editingId === id) root.cancelEdit()
  }

  function clearDone() {
    var next = []
    for (var i = 0; i < root.todos.length; i++) {
      if (!root.todos[i].done) next.push(root.todos[i])
    }
    root.persist(next)
    if (root.editingId !== "" && !Model.hasTodo(next, root.editingId)) root.cancelEdit()
    if (root.doneOnly && Model.doneCount(next) === 0) root.doneOnly = false
  }

  function createTag() {
    var tag = Model.cleanTag(newTagField.text)
    if (tag === "") {
      newTagField.forceActiveFocus()
      return
    }
    if (!Model.hasTagEntry(root.tags, tag)) root.persist(root.todos, root.tags.concat([tag]))
    newTagField.text = ""
  }

  function deleteTag(tag) {
    var key = Model.tagKey(tag)
    var nextTags = []
    for (var i = 0; i < root.tags.length; i++) {
      if (Model.tagKey(root.tags[i]) !== key) nextTags.push(root.tags[i])
    }
    var nextTodos = []
    for (var j = 0; j < root.todos.length; j++) {
      nextTodos.push(Model.tagKey(root.todos[j].tag) === key
        ? Model.cloneWith(root.todos[j], { tag: "" })
        : root.todos[j])
    }
    root.persist(nextTodos, nextTags)
    root.pendingTagDelete = ""
    if (Model.tagKey(root.tagFilter) === key) root.tagFilter = ""
    if (Model.tagKey(addTag.text) === key) addTag.text = ""
    if (Model.tagKey(editTag.text) === key) editTag.text = ""
  }

  function setDateField(field, mode) {
    if (mode === "today") field.text = root.today
    else if (mode === "tomorrow") field.text = root.tomorrow
    else field.text = ""
    if (field === addDate) root.addDateInvalid = false
    if (field === editDate) root.editDateInvalid = false
  }

  function toggleCountMode() {
    var next = root.countMode === "due" ? "total" : "due"
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry.countMode = next

    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  onOpenedChanged: if (opened) {
    root.clockTick++
    root.editingId = ""
    root.detailsOpen = false
    root.pendingTagDelete = ""
    root.addDateInvalid = false
    root.editDateInvalid = false
    storeFile.reload()
    Qt.callLater(function() { addTitle.forceActiveFocus() })
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: root.clockTick++
  }

  Process {
    id: ensureStateDir
    command: ["mkdir", "-p", root.stateDir]
    onExited: storeFile.reload()
  }

  Component.onCompleted: ensureStateDir.running = true

  Store {
    id: storeFile
    path: root.storePath
    onLoaded: root.loadStore(text())
    onLoadFailed: root.loadStore("")
    onFileChanged: reload()
  }

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰄱 " + Commons.I18n.formatNumber(root.barCount)
    foreground: root.foreground
    fontFamily: root.fontFamily
    tooltipText: root.barTooltip
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.toggleCountMode()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(420))
    contentHeight: popup.fittedContentHeight(contentColumn.implicitHeight, Style.space(640))

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: function(event) {
        if (root.editingId !== "") root.cancelEdit()
        else if (root.detailsOpen) root.detailsOpen = false
        else root.close()
        event.accepted = true
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

        Column {
          id: contentColumn
          width: flick.width
          spacing: Style.space(10)

          PanelHero {
            width: parent.width
            title: strings.t("app.title")
            meta: strings.t("hero.meta")
              .arg(Commons.I18n.formatNumber(root.openCount))
              .arg(Commons.I18n.formatNumber(root.dueCount))
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: "󰄱"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
            trailingControl: Component {
              Button {
                text: root.countMode === "due" ? strings.t("count.due") : strings.t("count.all")
                tooltipText: strings.t("count.tooltip")
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                horizontalPadding: Style.space(8)
                onClicked: root.toggleCountMode()
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.editingId === ""

            RowLayout {
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: addTitle
                Layout.fillWidth: true
                placeholderText: strings.t("add.placeholder")
                foreground: root.foreground
                font.family: root.fontFamily
                onAccepted: root.addTodo()
              }

              Button {
                text: strings.t("add.button")
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.addTodo()
              }
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(6)

              Button {
                text: root.detailsOpen ? strings.t("add.hideDetails") : strings.t("add.details")
                iconText: root.detailsOpen ? "󰅃" : "󰅀"
                bordered: false
                foreground: root.dim
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                horizontalPadding: Style.space(6)
                onClicked: root.detailsOpen = !root.detailsOpen
              }

              Item { Layout.fillWidth: true }
            }

            Column {
              width: parent.width
              spacing: Style.space(6)
              visible: root.detailsOpen

              RowLayout {
                width: parent.width
                spacing: Style.space(4)

                TextField {
                  id: addDate
                  Layout.fillWidth: true
                  placeholderText: strings.t("field.datePlaceholder")
                  foreground: root.foreground
                  font.family: root.fontFamily
                  onTextChanged: root.addDateInvalid = false
                  onAccepted: root.addTodo()
                }

                Button {
                  text: strings.t("date.today")
                  bordered: true
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(8)
                  onClicked: root.setDateField(addDate, "today")
                }

                Button {
                  text: strings.t("date.tomorrow")
                  bordered: true
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(8)
                  onClicked: root.setDateField(addDate, "tomorrow")
                }

                Button {
                  iconText: "󰅖"
                  tooltipText: strings.t("date.clear")
                  bordered: false
                  foreground: root.dim
                  fontFamily: root.fontFamily
                  horizontalPadding: Style.space(4)
                  onClicked: root.setDateField(addDate, "")
                }
              }

              Text {
                width: parent.width
                visible: root.addDateInvalid
                textFormat: Text.PlainText
                text: strings.t("date.invalid")
                color: root.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              TextField {
                id: addTag
                width: parent.width
                placeholderText: strings.t("field.tagPlaceholder")
                foreground: root.foreground
                font.family: root.fontFamily
                onAccepted: root.addTodo()
              }

              Flow {
                width: parent.width
                spacing: Style.space(4)
                visible: root.tags.length > 0

                Repeater {
                  model: root.tags

                  FilterChip {
                    label: modelData
                    tint: root.tagColor(modelData)
                    compact: true
                    onClicked: addTag.text = modelData
                  }
                }
              }

              TextField {
                id: addDesc
                width: parent.width
                placeholderText: strings.t("field.descriptionPlaceholder")
                foreground: root.foreground
                font.family: root.fontFamily
                onAccepted: root.addTodo()
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.editingId !== "" && root.editingTodo !== null

            PanelSectionHeader {
              width: parent.width
              text: strings.t("edit.title")
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            TextField {
              id: editTitle
              width: parent.width
              placeholderText: strings.t("add.placeholder")
              foreground: root.foreground
              font.family: root.fontFamily
              onAccepted: root.saveEdit()
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(4)

              TextField {
                id: editDate
                Layout.fillWidth: true
                placeholderText: strings.t("field.datePlaceholder")
                foreground: root.foreground
                font.family: root.fontFamily
                onTextChanged: root.editDateInvalid = false
                onAccepted: root.saveEdit()
              }

              Button {
                text: strings.t("date.today")
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                horizontalPadding: Style.space(8)
                onClicked: root.setDateField(editDate, "today")
              }

              Button {
                text: strings.t("date.tomorrow")
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                horizontalPadding: Style.space(8)
                onClicked: root.setDateField(editDate, "tomorrow")
              }

              Button {
                iconText: "󰅖"
                tooltipText: strings.t("date.clear")
                bordered: false
                foreground: root.dim
                fontFamily: root.fontFamily
                horizontalPadding: Style.space(4)
                onClicked: root.setDateField(editDate, "")
              }
            }

            Text {
              width: parent.width
              visible: root.editDateInvalid
              textFormat: Text.PlainText
              text: strings.t("date.invalid")
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            TextField {
              id: editTag
              width: parent.width
              placeholderText: strings.t("field.tagPlaceholder")
              foreground: root.foreground
              font.family: root.fontFamily
              onAccepted: root.saveEdit()
            }

            Flow {
              width: parent.width
              spacing: Style.space(4)
              visible: root.tags.length > 0

              Repeater {
                model: root.tags

                FilterChip {
                  label: modelData
                  tint: root.tagColor(modelData)
                  compact: true
                  onClicked: editTag.text = modelData
                }
              }
            }

            TextField {
              id: editDesc
              width: parent.width
              placeholderText: strings.t("field.descriptionPlaceholder")
              foreground: root.foreground
              font.family: root.fontFamily
              onAccepted: root.saveEdit()
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(6)
              Layout.alignment: Qt.AlignLeft

              Button {
                text: strings.t("edit.save")
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.saveEdit()
              }

              Button {
                text: strings.t("edit.cancel")
                bordered: false
                foreground: root.dim
                fontFamily: root.fontFamily
                onClicked: root.cancelEdit()
              }

              Item { Layout.fillWidth: true }

              Button {
                text: strings.t("edit.delete")
                bordered: false
                foreground: root.urgent
                fontFamily: root.fontFamily
                onClicked: root.deleteTodo(root.editingId)
              }
            }
          }

          Flow {
            width: parent.width
            spacing: Style.space(4)

            FilterChip {
              label: strings.t("filter.all")
              tint: root.foreground
              active: root.tagFilter === "" && !root.doneOnly
              onClicked: root.clearFilters()
            }

            FilterChip {
              label: root.doneCount > 0
                ? strings.t("filter.doneCount").arg(Commons.I18n.formatNumber(root.doneCount))
                : strings.t("filter.done")
              tint: root.accent
              active: root.doneOnly
              onClicked: root.setDoneFilter()
            }

            Repeater {
              model: root.tags

              FilterChip {
                label: modelData
                tint: root.tagColor(modelData)
                active: !root.doneOnly && Model.tagKey(root.tagFilter) === Model.tagKey(modelData)
                onClicked: root.setTagFilter(modelData)
              }
            }

            FilterChip {
              label: strings.t("tags.manage")
              tint: root.dim
              active: root.tagsOpen
              onClicked: {
                root.tagsOpen = !root.tagsOpen
                if (!root.tagsOpen) root.pendingTagDelete = ""
              }
            }
          }

          RowLayout {
            width: parent.width
            visible: root.doneCount > 0
            spacing: Style.space(6)

            Item { Layout.fillWidth: true }

            Button {
              text: strings.t("done.clear").arg(Commons.I18n.formatNumber(root.doneCount))
              tooltipText: strings.t("done.clearTooltip")
              bordered: true
              foreground: root.urgent
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              horizontalPadding: Style.space(8)
              onClicked: root.clearDone()
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(6)
            visible: root.tagsOpen

            PanelSectionHeader {
              width: parent.width
              text: strings.t("tags.title")
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: newTagField
                Layout.fillWidth: true
                placeholderText: strings.t("tags.addPlaceholder")
                foreground: root.foreground
                font.family: root.fontFamily
                onAccepted: root.createTag()
              }

              Button {
                text: strings.t("tags.add")
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.createTag()
              }
            }

            Flow {
              width: parent.width
              spacing: Style.space(4)
              visible: root.tags.length > 0

              Repeater {
                model: root.tags

                Row {
                  spacing: Style.space(2)

                  TagPill {
                    label: modelData
                    tint: root.tagColor(modelData)
                  }

                  Button {
                    text: "󰅖"
                    tooltipText: strings.t("tags.delete")
                    bordered: false
                    foreground: root.dim
                    fontFamily: root.fontFamily
                    fontSize: Style.font.bodySmall
                    horizontalPadding: Style.space(3)
                    verticalPadding: Style.space(1)
                    onClicked: root.pendingTagDelete = modelData
                  }
                }
              }
            }

            Text {
              width: parent.width
              visible: root.tags.length === 0
              textFormat: Text.PlainText
              text: strings.t("tags.empty")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Column {
              width: parent.width
              spacing: Style.space(4)
              visible: root.pendingTagDelete !== ""

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: strings.t("tags.deleteConfirm").arg(root.pendingTagDelete)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Row {
                spacing: Style.space(6)

                Button {
                  text: strings.t("tags.deleteAction")
                  bordered: false
                  foreground: root.urgent
                  fontFamily: root.fontFamily
                  onClicked: root.deleteTag(root.pendingTagDelete)
                }

                Button {
                  text: strings.t("edit.cancel")
                  bordered: false
                  foreground: root.dim
                  fontFamily: root.fontFamily
                  onClicked: root.pendingTagDelete = ""
                }
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(4)
            visible: root.todayTodos.length > 0

            PanelSectionHeader {
              width: parent.width
              text: strings.t("section.today")
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.todayTodos

              TodoRow {
                width: parent.width
                todo: modelData
                hideDate: true
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(4)
            visible: root.otherTodos.length > 0

            PanelSectionHeader {
              width: parent.width
              text: root.doneOnly ? strings.t("section.done") : strings.t("section.all")
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.otherTodos

              TodoRow {
                width: parent.width
                todo: modelData
              }
            }
          }

          Text {
            width: parent.width
            visible: root.todayTodos.length === 0 && root.otherTodos.length === 0
            textFormat: Text.PlainText
            text: root.doneOnly
              ? strings.t("empty.done")
              : (root.tagFilter !== "" ? strings.t("empty.filtered") : strings.t("empty.none"))
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            topPadding: Style.space(8)
          }
        }
      }
    }
  }

  component TodoRow: Item {
    id: row
    property var todo: null
    property bool hideDate: false

    width: parent ? parent.width : Style.space(320)
    implicitHeight: rowLayout.implicitHeight + Style.space(8)
    height: implicitHeight

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: rowHover.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
    }

    MouseArea {
      id: rowHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.beginEdit(row.todo)
    }

    RowLayout {
      id: rowLayout
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(4)
      anchors.rightMargin: Style.space(4)
      spacing: Style.space(6)

      Button {
        Layout.alignment: Qt.AlignTop
        text: row.todo && row.todo.done ? "󰄲" : "󰄱"
        foreground: row.todo && row.todo.done ? root.accent : root.foreground
        tooltipText: row.todo && row.todo.done ? strings.t("tooltip.undone") : strings.t("tooltip.done")
        bordered: false
        fontFamily: root.fontFamily
        horizontalPadding: Style.space(4)
        verticalPadding: Style.space(2)
        onClicked: root.toggleTodo(row.todo.id)
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(2)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: row.todo ? row.todo.title : ""
            color: row.todo && row.todo.done ? root.dim : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.strikeout: !!row.todo && row.todo.done
            elide: Text.ElideRight
            maximumLineCount: 1
          }

          TagPill {
            visible: !!row.todo && row.todo.tag !== ""
            label: row.todo ? row.todo.tag : ""
            tint: root.tagColor(row.todo ? row.todo.tag : "")
          }

          Text {
            visible: !row.hideDate && !!row.todo && row.todo.date !== ""
            textFormat: Text.PlainText
            text: root.dateLabel(row.todo ? row.todo.date : "")
            color: root.isOverdue(row.todo ? row.todo.date : "", row.todo ? row.todo.done : false) ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Text {
          visible: !!row.todo && row.todo.description !== ""
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: row.todo ? row.todo.description : ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
          maximumLineCount: 2
          elide: Text.ElideRight
        }
      }

      Button {
        visible: rowHover.containsMouse
        text: "󰅖"
        tooltipText: strings.t("tooltip.delete")
        bordered: false
        foreground: root.dim
        fontFamily: root.fontFamily
        horizontalPadding: Style.space(4)
        onClicked: root.deleteTodo(row.todo.id)
      }
    }
  }

  component TagPill: Rectangle {
    id: pill
    property string label: ""
    property color tint: root.foreground

    implicitWidth: pillText.implicitWidth + Style.space(10)
    implicitHeight: pillText.implicitHeight + Style.space(3)
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    color: root.tagTint(pill.label, 0.14)
    border.width: 1
    border.color: root.tagTint(pill.label, 0.42)

    Text {
      id: pillText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: pill.label
      color: pill.tint
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  component FilterChip: Rectangle {
    id: chip
    property string label: ""
    property color tint: root.foreground
    property bool active: false
    property bool compact: false
    signal clicked()

    implicitWidth: chipText.implicitWidth + (chip.compact ? Style.space(10) : Style.space(16))
    implicitHeight: chipText.implicitHeight + Style.space(6)
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    color: Qt.rgba(chip.tint.r, chip.tint.g, chip.tint.b, chip.active ? 0.22 : 0.1)
    border.width: 1
    border.color: Qt.rgba(chip.tint.r, chip.tint.g, chip.tint.b, chip.active ? 0.65 : 0.3)
    scale: chipMouse.pressed ? 0.97 : 1

    Behavior on scale {
      NumberAnimation {
        duration: Style.duration(120)
        easing.type: Easing.OutCubic
      }
    }

    Text {
      id: chipText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: chip.label
      color: chip.tint
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.clicked()
    }
  }
}
