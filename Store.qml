import QtQuick
import Quickshell.Io

FileView {
  id: store
  watchChanges: true
  atomicWrites: true
  printErrors: false
}
