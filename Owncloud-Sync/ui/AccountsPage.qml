import QtQuick 2.4
import Ubuntu.Components 1.3
import "../components"
import Ubuntu.OnlineAccounts 2.0

import QtQuick.LocalStorage 2.0


Page {
    id: accountsPage

    property var db
    property int debounce: 0

    /* load current data from DB */
    function loadDB() {

        accountListModel.clear();

        accountsPage.db = LocalStorage.openDatabaseSync("UBsync", "1.0", "UBsync", 1000000);

        console.log("Loading accountsPage data");

        accountsPage.db.transaction(
                    function(tx) {
                        // load selected account
                        var rs = tx.executeSql('SELECT * FROM SyncAccounts');

                        for(var i = 0; i < rs.rows.length; i++) {
                            console.log("Loading accountsPage: " + rs.rows.item(i).accountName + "; CNT: " + accounts.count + "; ID: " + rs.rows.item(i).accountID)
                            for (var j = 0; j < accounts.count; j++) {
                                if (accounts.get(j, "account").accountId === rs.rows.item(i).accountID) {
                                    console.log("Loading accountsPage: " + rs.rows.item(i).accountName + "; " + accounts.count + "; " + accounts.get(j, "account").accountId)
                                    /* Add only enabled accounts to the list */
                                    accountListModel.append({"accountID": rs.rows.item(i).accountID, "accountName": rs.rows.item(i).accountName})
                                }
                            }
                            }
                        }
                )

        accountList.forceLayout();
    }

    /* remove account */
    function removeAccount(accountID) {

        accountListModel.clear();

        accountsPage.db = LocalStorage.openDatabaseSync("UBsync", "1.0", "UBsync", 1000000);

        console.log("Removing account " + accountID)

        accountsPage.db.transaction(
                    function(tx) {
                        // remove selected account from DB
                        var rs = tx.executeSql('DELETE FROM SyncAccounts WHERE accountID = (?)', [accountID]);
                    }
                )

        // TODO - disable account in online accounts ?

        accountsPage.loadDB();
        accountList.forceLayout();
    }

    Connections {
            target: accountsPage

            /*onTargetChanged: {
                console.log("accountsPage changed")
                accountsPage.loadDB()
            }*/

            onActiveChanged: {
                /* re-render anytime page is shown */
                console.log("accountsPage activated")
                accountsPage.loadDB()
            }
        }

    ListModel {
        id: accountListModel
        Component.onCompleted: {
            console.log("accountsPage created")

            accountsPage.loadDB()
        }
    }


    header: PageHeader {
        id: header
        title: i18n.tr("Online Accounts")

        trailingActionBar{
            actions: [
                /* TODO: change icon to a custom "add NextCloud icon" */
                Action {
                    iconName: "add"
                    onTriggered: {
                        //apl.addPageToNextColumn(accountsPage, Qt.resolvedUrl("EditAccount.qml"), {accountID: accounts.get(accounts.count-1, "account").accountId, defaultAccountName: accounts.get(accounts.count-1, "account").displayName, remoteAddress: accounts.get(accounts.count-1, "account").account.settings.host})

                        console.log("Add NextCloud account.")
                        accounts.requestAccess(accounts.applicationId + "_nextcloud", {})
                    }
                },

                /* TODO: change icon to a custom "add OwnCloud icon" */
                Action {
                    iconName: "add"
                    onTriggered: {
                        console.log("Add OwnCloud account.")
                        accounts.requestAccess(accounts.applicationId + "_owncloud", {})
                    }
                }
            ]
        }
    }

    Timer {
        // This timer checks if a new account was added
        id: newAccountTimer
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            if (accounts.count > accountListModel.count) {
                accountsPage.debounce = accountsPage.debounce + 1
                accountsPage.loadDB()
            } else {
                accountsPage.debounce = 0
            }
            if (accountsPage.debounce > 2) {
                accountsPage.debounce = 0
                console.log("newAccountTimer diff: " + accounts.count + "; " +  accountListModel.count)
                accountConnection.target = accounts.get(accounts.count - 1, "account")
                accounts.get(accounts.count-1, "account").authenticate({})
            }
        }
    }

    Connections {
          id: accountConnection
          target: null
          onAuthenticationReply: {
              var reply = authenticationData

              if ("errorCode" in reply) {
                  console.warn("Authentication error: " + reply.errorText + " (" + reply.errorCode + ")")
                  // TODO: report an error to user ?

              } else {
                  apl.addPageToNextColumn(accountsPage, Qt.resolvedUrl("EditAccount.qml"), {accountID: target.accountId, defaultAccountName: target.displayName, remoteAddress: target.settings.host, remoteUser: reply.Username})
              }

          }
    }

    AccountModel {
        id: accounts
        applicationId: "ubsync_UBsync"
    }

    Item {
        //Shown only if there are no items in accounts
        anchors{centerIn: parent}

        Label{
            visible: !accountListModel.count
            text: i18n.tr("No accounts, press")
            anchors{horizontalCenter: parent.horizontalCenter; bottom: addIcon.top; bottomMargin: units.gu(2)}
        }

        Icon {
            id: addIcon
            visible: !accountListModel.count
            name: "add"
            width: units.gu(4)
            height: width
            anchors{centerIn: parent}
        }

        Label{
            visible: !accountListModel.count
            text: i18n.tr("on the panel to add a new accounts")
            anchors{horizontalCenter: parent.horizontalCenter; top: addIcon.bottom; topMargin: units.gu(2)}
        }
    }

    ListView {
        id: accountList
        model: accountListModel
        anchors{left:parent.left; right:parent.right; top:header.bottom; bottom:parent.bottom; bottomMargin:units.gu(2)}
        clip: true
        visible: accountListModel.count

        delegate: ListItem {
            height: accountColumn.height
            anchors{left:parent.left; right:parent.right}

            onClicked: {
                apl.addPageToNextColumn(accountsPage, Qt.resolvedUrl("EditAccount.qml"), {accountID: accountListModel.get(index).accountID})
            }

            Column {
                id: accountColumn
                height: units.gu(12)

                anchors.leftMargin: units.gu(2)

                spacing: units.gu(1)
                anchors {
                    top: parent.top; left: parent.left; right: parent.right; margins:units.gu(2)
                }

                Rectangle {
                    id: accountIcon
                    color: "steelblue"
                    width: units.gu(9)
                    height: width
                    border.width: 0
                    radius: 10
                    anchors {
                       left: parent.left; top: parent.top
                    }
                }

                Text {
                    id: accountIconText
                    text: accountListModel.get(index).accountName.charAt(0).toUpperCase()
                    color: "white"
                    font.pixelSize: units.gu(6)
                    anchors {
                       horizontalCenter: accountIcon.horizontalCenter; verticalCenter: accountIcon.verticalCenter
                    }
                }

                Text {
                    id: accountName
                    text: accountListModel.get(index).accountName
                    height: units.gu(6)
                    font.pixelSize: units.gu(3)
                    anchors.leftMargin: units.gu(2)
                    anchors {
                       left: accountIcon.right; top: parent.top
                    }
                }

                Text {
                    id: accountID
                    text: accountListModel.get(index).accountID
                    font.pixelSize: units.gu(2)
                    anchors.leftMargin: units.gu(2)
                    anchors {
                       left: accountIcon.right; top: accountName.bottom
                    }
                }

                /* TODO display number of sync targets ? */

            }


            leadingActions: ListItemActions {
                actions: [
                    Action {
                        iconName: "delete"
                        text: ""
                        onTriggered: {
                            accountsPage.removeAccount(accountListModel.get(index).accountID)
                        }
                    }
                ]
            }

            trailingActions: ListItemActions {
                actions: [
                    Action {
                        iconName: "edit"
                        text: ""
                        onTriggered: {
                            apl.addPageToNextColumn(accountsPage, Qt.resolvedUrl("EditAccount.qml"), {accountID: accountListModel.get(index).accountID})
                        }
                    },

                    Action {
                        iconName: "note-new"
                        text: ""
                        onTriggered: {
                            apl.addPageToNextColumn(accountsPage, Qt.resolvedUrl("EditTarget.qml"), {targetID: 0, accountID: accountListModel.get(index).accountID})
                        }
                    }
                ]
            }
        }
    }



}