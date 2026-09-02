pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
  id: panel
  required property var controller
  Layout.fillWidth: true
  spacing: Style.spacing.md

  function sectionY(section) {
    var pages = [generalPage, appearancePage, servicesPage, performancePage, discoveryPage, packagesPage]
    for (var index = 0; index < pages.length; index++) {
      var value = pages[index].sectionY(section)
      if (value >= 0) return pages[index].mapToItem(panel, 0, value).y
    }
    return 0
  }

  P2PGeneralSettings { id: generalPage; controller: panel.controller }
  P2PAppearanceSettings { id: appearancePage; controller: panel.controller }
  P2PServicesSettings { id: servicesPage; controller: panel.controller }
  P2PPerformanceSettings { id: performancePage; controller: panel.controller }
  P2PDiscoverySettings { id: discoveryPage; controller: panel.controller }
  P2PPackagesSettings { id: packagesPage; controller: panel.controller }

}
