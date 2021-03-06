import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_chat/chat_p/api_request.dart';
import 'package:firebase_chat/chat_p/shared_preferences_file.dart';
import 'package:firebase_chat/screens/inbox_p/models/group.dart';
import 'package:firebase_chat/screens/inbox_p/models/user.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'local_constant.dart';
import 'api_constant.dart';

// In case we decide to implement another kind of authorization method
abstract class FireBaseStoreBase {

  // Sent new message
  Future<dynamic> sentMessageFireBase({Key key,String uId, String peerId, String groupChatId,
      String name, String content, int type, bool isFromGroup});
  //Sent notification
  Future<dynamic> sentFCMNotificationFireBase({Key key,receiverId,String senderName,String uId
    ,String content,bool isFromGroup,bool isFirstTime,String notificationSentApi});
  //Upload file on fire-base
  Future<dynamic> uploadFileFireBase({Key key,File imageFile});
  //Update notification token of user
  Future<dynamic> updateFireBaseToken({Key key, String uId, String token});

  //******************* User details  ******************************************
  //Add new user on fire-base
  Future<dynamic> addNewUserOnFireBase({Key key, String uId, String nickName, String imageUrl});
  //Get single fire-base user details
  Future<dynamic> getUsersListFireBase();
  //Get single fire-base user details
  Future<dynamic> getUserDetailsFireBase({Key key,String uId});
  //Update fire-base user details
  Future<dynamic> updatedUserProfileFireBase({Key key, String uId, String nickName, String imageUrl});
  //******************* User Details ******************************************

  //******************* Group ******************************************
  //Get total joined group count
  Future<dynamic> getGroupCountFireBase({Key key, String uId});
  //Get fire-base group list privet, public and all
  Future<dynamic> getGroupsFireBase({Key key, String uId, bool isAll});
  //Get group details/info
  Future<dynamic> getGroupDetailsFireBase({Key key,String uId});
  //Create group on fire-base
  Future<dynamic> createChatGroupFireBase({Key key, chatGroup, user,usersList,String notificationSentApi});
  Future<dynamic> inviteUserInGroupFireBase({Key key, chatGroup,usersList,String notificationSentApi});
  //Update group details/info
  Future<dynamic> updatedChatGroupFireBase({Key key,chatGroup, user});

  //Join any group
  Future<dynamic> joinChatGroupFireBase({Key key, groupId, user});
  //Left group
  Future<dynamic> leftChatGroupFireBase({Key key, String groupId, user});
  //Delete group
  Future<dynamic> deleteChatGroupFireBase({Key key,String groupId});
 //******************* End Group ******************************************


  //******************* User Inbox ******************************************
  //Get inbox data list from fire-base
  Future<dynamic> getChatInboxFireBase({Key key, String uId,bool isAll});
  //inbox message update
  Future<dynamic> inboxUpdateMessageReadStatusFireBase({Key key,String uId,bool isGroup});


  Future<dynamic> setBaseUrl({Key key,String url});
  Future<dynamic> setNotificationUrl({Key key,String url});
  //This below functions are using internally
 /* Future<dynamic> inboxNewEntryFireBase({Key key,String selfUid,String uId,ChatGroups chatGroup,
      User user,@required bool isFromGroup});*/
  /*Future<dynamic> inboxUpdateGroupJoinStatusFireBase({Key key,String selfUid,
      String uId,ChatGroups chatGroup,User user,bool isFromGroup});*/
//******************* End User Inbox ******************************************

}

class FireBaseStore implements FireBaseStoreBase {
  FirebaseAuth fireBaseAuth = FirebaseAuth.instance;
  Firestore fireBaseStore = Firestore.instance;

  //Get inbox from fire-base
  Future<dynamic> getChatInboxFireBase({Key key,String uId,bool isAll}) async {
    try {
      //If want all list
      if (isAll) {
        uId = null;
      }
      if (uId != null) {
        //Get List of group or messages main node
        final QuerySnapshot result = await Firestore.instance
            .collection('users_inbox').document(uId)
            .collection('inbox_user')
            .orderBy('timestamp', descending: true)
            .getDocuments();
        final List<DocumentSnapshot> listOfInbox = result.documents;
        //Get selected user data from list
        if (listOfInbox != null && listOfInbox.length > 0) {
          return listOfInbox;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      print(e);
      return null;
    }
  }

  //Inbox update at new message and reade status
  Future<dynamic> inboxUpdateMessageReadStatusFireBase({Key key,String uId,bool isGroup}) async{
    if(isGroup==null){
      isGroup = false;
    }
    try {
      sharedPreferencesFile.readStr('chatUid').then((selfUid){
        if(selfUid!=null && uId!=null){
          try {
            //Update in self
            Firestore.instance
                .collection('users_inbox')
                .document(selfUid)
                .collection('inbox_user')
                .document(uId)
                .updateData(
                {
                  'isReded':true
                }
            );
          } catch (e) {
            print(e);
          }
        }
      });
      return true;
    } on Exception catch (e) {
      // TODO
      print("firebase error $e");
      return false;
    }
  }

  //Send Message group
  Future<dynamic> sentMessageFireBase({Key key,String uId, String peerId, String groupChatId,
    String name, String content, int type, bool isFromGroup}) async {
    //Check group id is created or not
    var documentReference = Firestore.instance
        .collection('messages')
        .document(groupChatId)
        .collection(groupChatId)
    // .document(timeStamp.toString());
        .document(DateTime.now().millisecondsSinceEpoch.toString());

    await Firestore.instance.runTransaction((transaction) async {
      await transaction.set(
        documentReference,
        {
          'idFrom': uId,
          'idTo': peerId,
          'name': name != null ? name : "NA",
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          //'timestamp': FieldValue.serverTimestamp().toString(),
          'content': content,
          'type': type
        },
      );
    });

    final QuerySnapshot result = await Firestore.instance
        .collection('messages')
        .where('id', isEqualTo: groupChatId)
        .getDocuments();
    final List<DocumentSnapshot> documents = result.documents;
    if (documents.length == 0) {
      try {
        await Firestore.instance
            .collection('messages')
            .document(groupChatId)
            .setData({
          'id': groupChatId,
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          'isGroup': isFromGroup
        });
        print("success $groupChatId");
        return "";
      } catch (e) {
        print(e);
        print("error $e");
        return "";
      }
    }
    return "";
  }

  //Delete group
  //Delete group
  Future<dynamic> deleteChatGroupFireBase({Key key,String groupId}) async {
    //Check group id is created or not
    try {
      if (groupId != null) {
        try{
          //Delete group from user inbox
          final QuerySnapshot groupDetails = await Firestore.instance
              .collection('user_groups')
              .where('gId', isEqualTo: groupId)
              .getDocuments();
          if(groupDetails!=null && groupDetails.documents!=null ){
            final List<DocumentSnapshot> documentsUser = groupDetails.documents;
            if(documentsUser!=null && documentsUser.length>0){
              DocumentSnapshot detailsTemp = documentsUser[0];
              List<dynamic> groupUsersList = detailsTemp["usersDetails"];
              if(groupUsersList!=null && groupUsersList.length>0){
                for(int i=0;i<groupUsersList.length;i++){
                  var singleUserDetails = groupUsersList[i];
                  if(singleUserDetails!=null){
                    try {
                      String userId = singleUserDetails["id"];
                      if(userId!=null){
                        var chatId = groupId;
                        await inboxUpdateGroupDeleteStatusFireBase(selfUid: userId, chatId: chatId,deleteStatus: true);
                      }
                    }
                    catch (e) {
                      print(e);
                    }
                  }
                }
              }
            }

          }
          print("Ok");
        }
        catch (e) {
          // TODO
          print("firebase error $e");
        }
        try {
          await Firestore.instance
              .collection("user_groups")
              .document(groupId)
              .updateData({"isDeletes": true});
          Fluttertoast.showToast(msg: 'Deleted successfully');
          return true;
        } on Exception catch (e) {
          // TODO
          print("firebase error $e");
          return false;
        }
      } else {
        return false;
      }
    } catch (e) {
      print(e);
      return false;
    }
  }


  //Upload image on fire-base
  Future<dynamic> uploadFileFireBase({Key key,File imageFile}) async {
    String imageUrl;
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      StorageReference reference =
      FirebaseStorage.instance.ref().child(fileName);
      StorageUploadTask uploadTask = reference.putFile(imageFile);
      StorageTaskSnapshot storageTaskSnapshot = await uploadTask.onComplete;
      String downloadUrl = await storageTaskSnapshot.ref
          .getDownloadURL(); //.then((downloadUrl) {
      imageUrl = downloadUrl;
      return imageUrl;
    } catch (e) {
      print(e);
      return imageUrl;
    }
  }

/*  //Upload image on fire-base
  Future<String> uploadFile(File imageFile) async {
    String imageUrl;
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      StorageReference reference =
      FirebaseStorage.instance.ref().child(fileName);
      StorageUploadTask uploadTask = reference.putFile(imageFile);
      StorageTaskSnapshot storageTaskSnapshot = await uploadTask.onComplete;
      String downloadUrl = await storageTaskSnapshot.ref
          .getDownloadURL(); //.then((downloadUrl) {
      imageUrl = downloadUrl;
      return imageUrl;
    } catch (e) {
      print(e);
      return imageUrl;
    }
  }*/

  //Add user details in fire-base users table
  Future<dynamic> addNewUserOnFireBase(
      {Key key, String uId, String nickName, String imageUrl}) async {
    try {
      if (uId != null && nickName != null) {
        // Check is already sign up
        final QuerySnapshot result = await Firestore.instance
            .collection('users')
            .where('id', isEqualTo: uId)
            .getDocuments();
        final List<DocumentSnapshot> documents = result.documents;
        if (documents.length == 0) {
          //Update data to server if new user
          Firestore.instance.collection('users').document(uId).setData({
            'nickName': nickName,
            'imageUrl': imageUrl,
            'id': uId,
            'createdAt': DateTime.now().millisecondsSinceEpoch.toString(),
            'chattingWith': null
          });
          return true;
        } else {
          return true;
        }
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<dynamic> updateFireBaseToken({Key key, String uId, String token}) async {
    try {
      if (uId != null) {
        Firestore.instance
            .collection('users')
            .document(uId)
            .updateData({'pushToken': token});
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  //Edit/Updated user details on fire-base
  Future<dynamic> updatedUserProfileFireBase(
      {Key key, String uId, String nickName, String imageUrl}) async {
    //Check group id is created or not
    try {
      if (uId != null) {
        String mid = uId;
        Map<String, String> data = new Map<String, String>();
        if (nickName != null && nickName.trim().length > 0) {
          data['nickName'] = nickName;
        }
        if (imageUrl != null && imageUrl.trim().length > 0) {
          data['imageUrl'] = imageUrl;
        }
        await Firestore.instance
            .collection("users")
            .document(mid)
            .updateData(data);
        return true;
      } else {
        return false;
      }
    } on Exception catch (e) {
      // TODO
      print("firebase error $e");
      return false;
    }
  }

  //Create group on fire-base
  createChatGroupFireBase({Key key, chatGroup, user,usersList,String notificationSentApi}) async {

    List<dynamic> userListTemp = new List();
    // Private group
    if(chatGroup.groupType==1){
    for(int i=0;i<usersList.length;i++){
    var uId =   usersList[i];
    var obj = {
    "name": "",
    "id": uId,
    "imageUrl": "",
    "pushToken": "",
    "isRequestNotAccepted": (user.documentID==uId)?false:true,
    };
    userListTemp.add(obj);
      }
    }
    //Public group
    else  if(chatGroup.groupType==0){
      var obj = {
        "name": user.firstName != null ? user.firstName : "",
        "id": user.documentID,
        "imageUrl": user.imageUrl,
        "pushToken": user.fcmToken,
        "isRequestNotAccepted": false,
      };
      userListTemp.add(obj);
    }

    var documentReference =
        await Firestore.instance.collection('user_groups').add({
      'createBy': chatGroup.createBy,
      'name': chatGroup.name,
      'subHeading': chatGroup.subHeading,
      'groupType': chatGroup.groupType,
      'gId': "",
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      'description': chatGroup.description,
      'totalUser': chatGroup.totalUser != null ? chatGroup.totalUser : 1,
      'image': chatGroup.image != null ? chatGroup.image : "",
      'usersDetails': userListTemp,
      'isDeletes': false
    });

    //Check group id is created or not
    if (documentReference != null && documentReference.documentID != null) {
      try {
        await Firestore.instance
            .collection('user_groups')
            .document(documentReference.documentID)
            .updateData({
          'gId': documentReference.documentID,
        });

        try{

          try{
            if(chatGroup.groupType==1) {
              for (int i = 0; i < usersList.length; i++) {
                await inboxNewEntryFireBase(
                    selfUid: usersList[i],
                    uId: documentReference.documentID,
                    chatGroup: chatGroup,
                    isFromGroup: true);
              }

              try {
                String currentLoggedInChatId = await sharedPreferencesFile.readStr("chatUid");
                var usersListTemp = usersList;
                if(usersListTemp!=null && usersListTemp.length>0 && currentLoggedInChatId!=null && usersListTemp.contains(currentLoggedInChatId)){
                  usersListTemp.remove(currentLoggedInChatId);
                }
                //Sent notification
                await sentFCMNotificationFireBaseByApi(receiverId : usersListTemp,senderName: chatGroup.name,content: "",isFromGroup: false,isFirstTime: true, uId: currentLoggedInChatId,isForGroupInvite: true,notificationSentApi:notificationSentApi);
              } catch (e) {
                print(e);
              }

            }
           else{
              //Add group in in box
              await inboxNewEntryFireBase(
                  selfUid: user.documentID,
                  uId: documentReference.documentID,
                  chatGroup: chatGroup,
                  isFromGroup: true);
            }
          }
          catch (e) {
            print(e);
          }


      }
      catch (e) {
        // TODO
        print("firebase error $e");
      }
        return ChatGroups(gId: documentReference.documentID);
      } on Exception catch (e) {
        // TODO
        print("firebase error $e");
        return null;
      }
    }
    else {
      return ChatGroups(gId: null);
    }
  }

  //Invite user in group on fire-base
  inviteUserInGroupFireBase({Key key, chatGroup,usersList,String notificationSentApi}) async {
    List<dynamic> userListTemp = new List();
    // Private group
    if(chatGroup.groupType==1){
    for(int i=0;i<usersList.length;i++){
    var uId =   usersList[i];
    var obj = {
    "name": "",
    "id": uId,
    "imageUrl": "",
    "pushToken": "",
    "isRequestNotAccepted": true,
    };
    userListTemp.add(obj);
      }
    }
    try {
      await Firestore.instance
          .collection("user_groups")
          .document(chatGroup.gId)
          .updateData({"usersDetails": FieldValue.arrayUnion(userListTemp)});

      try{
        if(chatGroup.groupType==1) {

          for (int i = 0; i < usersList.length; i++) {
            await inboxNewEntryFireBase(
                selfUid: usersList[i],
                uId: chatGroup.gId,
                chatGroup: chatGroup,
                isFromGroup: true);
          }

          try {
            String currentLoggedInChatId = await sharedPreferencesFile.readStr("chatUid");
            //Sent notification
            await sentFCMNotificationFireBaseByApi(receiverId : usersList,senderName: chatGroup.name,content: "",isFromGroup: false,isFirstTime: true, uId: currentLoggedInChatId,isForGroupInvite: true,notificationSentApi: notificationSentApi);
          }
          catch (e) {
            print(e);
          }

        }
      }
      catch (e) {
        print(e);
      }
    }
    catch (e) {
      print(e);
    }
    print("firebase error $userListTemp");
  }

  //Get group count on fire-base
  Future<dynamic> getGroupsFireBase({Key key, String uId, bool isAll}) async {
    try {
      //If want all list
      if (isAll) {
        uId = null;
      }
      if (uId != null || isAll) {
        String createById = uId;
        CollectionReference ref = Firestore.instance.collection('user_groups');
        final QuerySnapshot result = await ref.where('isDeletes',isEqualTo: false).getDocuments();
        List<DocumentSnapshot> documents = result.documents;
        if (documents.length != 0) {
        documents.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));  //Sort list according time (Arrange list according time)
        documents =  documents.reversed.toList();   // revers list according time new created will come on top
          List<DocumentSnapshot> documentsTemp = new List();
          if (!isAll && createById != null) {
            for (var document in documents) {
              String groupMemberList;
              if (document['usersDetails'] != null) {
                groupMemberList = document['usersDetails'].toString();
              }
              if (document['createBy'] == createById ||
                  (groupMemberList != null &&
                      groupMemberList.contains(createById))) {
                documentsTemp
                    .add(document); //return selected group details list
              }
            }
            if (documentsTemp.length <= 0) {
              return null;
            }
            else {
              return documentsTemp; //return selected group details list
            }
          }
          else {
            documentsTemp.addAll(documents);
            if (documentsTemp.length <= 0) {
              return null;
            } else {
              return documentsTemp;
            }
            //Return all Group details list
          }
        }
        return null;
      } else {
        return null;
      }
    } catch (e) {
      print(e);
    }
  }


  //Get fire-base users list from fire-base
  Future<dynamic> getUsersListFireBase() async {
    try {
        final QuerySnapshot result = await Firestore.instance
            .collection('users')
            .getDocuments();
        final List<DocumentSnapshot> documentsUser = result.documents;
        if (documentsUser.length > 0) {
          return documentsUser;
        } else {
          return null;
        }
    } catch (e) {
      print(e);
      return null;
    }
  }

  //Get firebse user details  from fire-base
  Future<dynamic> getUserDetailsFireBase(
      {Key key, @required String uId}) async {
    try {
      if (uId != null) {
        final QuerySnapshot result = await Firestore.instance
            .collection('users')
            .where('id', isEqualTo: uId)
            .getDocuments();
        final List<DocumentSnapshot> documentsUser = result.documents;
        if (documentsUser.length > 0) {
          DocumentSnapshot mDocumentSnapshotUser = documentsUser[0];
          if (mDocumentSnapshotUser != null) {
            return mDocumentSnapshotUser;
          } else {
            return null;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      print(e);
      return null;
    }
  }

  //Get firebse user details  from fire-base
  Future<dynamic> getGroupDetailsFireBase(
      {Key key, @required String uId}) async {
    try {
      if (uId != null) {
        final QuerySnapshot result = await Firestore.instance
            .collection('user_groups')
            .where('gId', isEqualTo: uId)
            .getDocuments();
        final List<DocumentSnapshot> documentsUser = result.documents;
        if (documentsUser.length > 0) {
          DocumentSnapshot mDocumentSnapshotUser = documentsUser[0];
          if (mDocumentSnapshotUser != null) {
            return mDocumentSnapshotUser;
          } else {
            return null;
          }
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      print(e);
      return null;
    }
  }


  //Get group count on fire-base
  Future<dynamic> getGroupCountFireBase({Key key, String uId}) async {
    try {
      if (uId != null) {
        String createById = uId;
        final QuerySnapshot result = await Firestore.instance
            .collection('user_groups')
            .where('isDeletes', isEqualTo: false)
            .getDocuments();
        final List<DocumentSnapshot> documents = result.documents;
        if (documents.length != 0) {
          List<DocumentSnapshot> documentsTemp = new List();
          for (var document in documents) {
            if (document != null) {
              String groupMemberList;
              if (document['usersDetails'] != null && !document['isDeletes']) {
                groupMemberList = document['usersDetails'].toString();
              }
              if (document['createBy'] == createById ||
                  (groupMemberList != null &&
                      groupMemberList.contains(createById))) {
                documentsTemp.add(document);
              }
            }
          }
          return documentsTemp;
        }
        return null;
      } else {
        return null;
      }
    } catch (e) {
      print(e);
    }
  }

  //Edit/Updated group details on fire-base
  Future<dynamic> updatedChatGroupFireBase({Key key,  chatGroup, user}) async {
    //Check group id is created or not
    try {
      if (chatGroup != null && chatGroup.gId != null) {
        String groupId = chatGroup.gId;
        await Firestore.instance
            .collection("user_groups")
            .document(groupId)
            .updateData({
          'name': chatGroup.name,
          'subHeading': chatGroup.subHeading,
          'description': chatGroup.description,
          'image': chatGroup.image != null ? chatGroup.image : "",
          'groupType': chatGroup.groupType,
        });
        Fluttertoast.showToast(msg: 'Updated successfully');
        return true;
      } else {
        return false;
      }
    } on Exception catch (e) {
      // TODO
      print("firebase error $e");
      Fluttertoast.showToast(msg: 'Update failed!');
      return false;
    }
  }



  //inbox creation and entry
  Future<dynamic> inboxNewEntryFireBase(
      {Key key,
      String selfUid,
      String uId,
      chatGroup,
      User user,
      @required bool isFromGroup}) async {
    if (isFromGroup == null) {
      isFromGroup = false;
    }
    try {
      if (uId != null) {
        // Check is already sign up
        /*var documentTemp =  await Firestore.instance
            .collection('users_inbox')
            .document(selfUid)
            .collection('inbox_user').limit(1).getDocuments();*/
            //.get();

        var documentTemp = await Firestore.instance
            .collection('users_inbox')
            .document(selfUid)
            .collection('inbox_user')
            .document(uId)
            .get();

        String imageUrl = "";
        String name = "";
        int groupType = 0;

        if (chatGroup != null) {
          name = chatGroup.name != null ? chatGroup.name : "";
          imageUrl = chatGroup.image != null ? chatGroup.image : "";
          groupType = chatGroup.groupType != null ? chatGroup.groupType : 0;
        } else if (user != null) {
          name = user.firstName != null ? user.firstName : "";
          imageUrl = user.imageUrl != null ? user.imageUrl : "";
        }
        //Update if already exist
        if (documentTemp != null)
        {
          if(documentTemp!=null &&  documentTemp.data == null) {
            if (isFromGroup) {
              try {
                String currentLoggedInChatId = await sharedPreferencesFile.readStr("chatUid");

                await Firestore.instance
                    .collection('users_inbox')
                    .document(selfUid)
                    .collection('inbox_user')
                    .document(uId)
                    .setData({
                  "isGroup": isFromGroup,
                  "isDeletes": false,
                  "isJoin": (groupType==1)?(currentLoggedInChatId!=null && currentLoggedInChatId==selfUid)?true:false:true,
                  "isBlock": false,
                  'isReded': true,
                  'last_message': "Welcome in group",
                  'image': imageUrl,
                  "id": uId,
                  'name': name,
                  'timestamp': DateTime
                      .now()
                      .millisecondsSinceEpoch
                      .toString(),
                });
              } catch (e) {
                // TODO
                print("firebase error $e");
              }
            }
            else if (!isFromGroup) {
              //Update data to server if new user
              Firestore.instance
                  .collection('users_inbox')
                  .document(selfUid)
                  .collection('inbox_user')
                  .document(uId)
                  .setData({
                "isGroup": isFromGroup,
                "isDeletes": false,
                "isJoin": true,
                "isBlock": false,
                'isReded': true,
                'last_message': "",
                'image': imageUrl,
                "id": uId,
                'name': name,
                'timestamp': DateTime
                    .now()
                    .millisecondsSinceEpoch
                    .toString(),
              });
            }
          }
          return true;
        }
        else {
          return false;
        }
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }



  //Inbox update at new message and reade status
  Future<dynamic> inboxUpdateNewMessageStatusFireBase({
    Key key,
    String selfUid,
    String chatId,
    String message,
    bool isGroup,
    receiverId
  }) async
  {
    if(isGroup==null){
      isGroup = false;
    }
    try {
      //Group chat
      if(isGroup){
        try {
          //Update in self
          await Firestore.instance
              .collection('users_inbox')
              .document(selfUid)
              .collection('inbox_user')
              .document(chatId)
              .updateData(
              {
                'isReded':true,
                'timestamp':DateTime.now().millisecondsSinceEpoch.toString(),
                'last_message':message
              }
          );
        }
        catch (e) {
          print(e);
        }
        try{
          for(int i=0;i<receiverId.length;i++)
          Firestore.instance
              .collection('users_inbox')
              .document(receiverId[i])
              .collection('inbox_user')
              .document(chatId)
              .updateData(
              {
                'isReded':false,
                'timestamp':DateTime.now().millisecondsSinceEpoch.toString(),
                'last_message':message}
          );
        }
        catch (e) {
          print(e);
        }
      }
      //One to one chat
      else{
       try {
         //Update in self
         await Firestore.instance
                     .collection('users_inbox')
                     .document(selfUid)
                     .collection('inbox_user')
                     .document(receiverId[0])
                     .updateData(
                     {
                       'isReded':true,
                       'timestamp':DateTime.now().millisecondsSinceEpoch.toString(),
                       'last_message':message
                     }
                 );
       } catch (e) {
         print(e);
       }
       try {
         await Firestore.instance
                     .collection('users_inbox')
                     .document(receiverId[0])
                     .collection('inbox_user')
                     .document(selfUid)
                     .updateData(
                     {
                       'isReded':false,
                       'timestamp':DateTime.now().millisecondsSinceEpoch.toString(),
                       'last_message':message
                     }
                 );
       } catch (e) {
         print(e);
       }
      }

      return true;
    } on Exception catch (e) {
      // TODO
      print("firebase error $e");
      return false;
    }
  }

  //Inbox update
  Future<dynamic> inboxUpdateGroupJoinStatusFireBase({Key key,String selfUid,String uId,ChatGroups chatGroup,User user,bool isJoinGroup,
      bool isDeleted,
      bool isBlocked,
      bool isFromGroup}) async {
    try {
      var documentTemp = await Firestore.instance
          .collection('users_inbox')
          .document(selfUid)
          .collection('inbox_user')
          .document(uId)
          .get();
      //Rejoin group
      if (documentTemp != null && documentTemp.data != null) {
        var data = documentTemp.data;
        data['timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
        if (isDeleted != null) {
          data['isDeletes'] = isDeleted;
        }
        if (isJoinGroup != null) {
          data['isJoin'] = isJoinGroup;
        }
        if (isBlocked != null) {
          data['isBlock'] = isBlocked;
        }
        Firestore.instance
            .collection('users_inbox')
            .document(selfUid)
            .collection('inbox_user')
            .document(uId)
            .updateData(data);
        return true;
      }
      //Add new id
      else {
        try{
          //Add group in inbox
          await inboxNewEntryFireBase(
              selfUid: selfUid,
              uId: uId,
              chatGroup: chatGroup,
              isFromGroup: true);
        }
        catch (e) {
          // TODO
          print("firebase error $e");
          return false;
        }
        return true;
      }
    } on Exception catch (e) {
      // TODO
      print("firebase error $e");
      return false;
    }
  }

  //Inbox update in case of delete group or left group
  Future<dynamic> inboxUpdateGroupDeleteStatusFireBase({Key key, String selfUid, String chatId, bool deleteStatus}) async {
    try {

      var documentTemp = await Firestore.instance
          .collection('users_inbox')
          .document(selfUid)
          .collection('inbox_user')
          .document(chatId)
          .get();
      //Rejoin group
      if (documentTemp != null && documentTemp.data != null) {
        var data = documentTemp.data;
        data['timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
        data['isDeletes'] = false;
        Firestore.instance
            .collection('users_inbox')
            .document(selfUid)
            .collection('inbox_user')
            .document(chatId)
            .updateData(data);
        return true;
      }
      //Add new id
      else {
        return false;
      }
    } on Exception catch (e) {
      // TODO
      print("firebase error $e");
      return false;
    }
  }

  //Send Message group
  Future<dynamic> sentFCMNotificationFireBase(
      {Key key,
      receiverId,
      String senderName,
      String uId,
      String content,String notificationSentApi,
      bool isFromGroup,
      bool isFirstTime}) async {
    try {

      //Add user in inbox
      if (!isFromGroup){
        String uName = await sharedPreferencesFile.readStr('user_name');
        String imageUser = await sharedPreferencesFile.readStr('imageUrl');
        User selfUserDetails = new User(firstName: uName, imageUrl: imageUser);
        User receiverUserDetails =
        new User(firstName: uName, imageUrl: imageUser);
        try{
          // Add inbox in self chat
          await inboxNewEntryFireBase(
              selfUid: uId,
              uId: receiverId[0],
              user: receiverUserDetails,
              isFromGroup: false);
        }
        catch (e) {
          // TODO
          print("firebase error $e");
        }
        try{
          // Add inbox in receiver
          await inboxNewEntryFireBase(
              selfUid: receiverId[0],
              uId: uId,
              user: selfUserDetails,
              isFromGroup: false);
        }
        catch (e) {
          // TODO
          print("firebase error $e");
        }
      }

      //Sent notification
      sentFCMNotificationFireBaseByApi(receiverId : receiverId,senderName: senderName,content: content,isFromGroup: false,isFirstTime: isFirstTime, uId: uId,notificationSentApi: notificationSentApi);
      try
      {
        String selfUid =
        await sharedPreferencesFile.readStr('chatUid');
        await inboxUpdateNewMessageStatusFireBase(selfUid: selfUid,chatId: uId,message: content,isGroup: isFromGroup,receiverId: receiverId);
      }
      catch (e) {
        print(e);
      }
    } catch (e) {
      print(e);
      return "";
    }
    return Future.value("Done");
  }

  //Send Message group
  Future<dynamic> sentFCMNotificationFireBaseByApi(
      {Key key,
        receiverId,
        String senderName,
        String uId,
        String content,String notificationSentApi,
        bool isFromGroup,bool isForGroupInvite,
        bool isFirstTime}) async {
    try {
      //Normal message all time not first time
      int notificationFor = notificationOneToOneSecondC;
      if (isFromGroup != null && isFromGroup) {
        notificationFor = notificationGroupSecondC;
      }
      //If start chat first time for one to one or group
      if (isFirstTime) {
        notificationFor = notificationOneToOneC;
        if (isFromGroup != null && isFromGroup) {
          notificationFor = notificationGroupC;
        }
      }
      if(isForGroupInvite!=null && isForGroupInvite){
        notificationFor = notificationGroupInviteC;
      }
      Map data = {
        "send_email": isFirstTime,
        "send_fcm": true,
        "store_notification": true,
        "receiver_uids": receiverId,
        "message": content,
        "type": notificationFor,
        "uid": uId //Sender Id
      };
      //Add chat group name
      if (notificationFor == notificationGroupC)
      data["group_name"] = senderName!=null ? senderName: "";

      //encode Map to JSON
      var requestBody = json.encode(data);
      sharedPreferencesFile.readStr(accessToken)
          .then((value) {
        String authorization = value;
        String notificationUrl =  ConstantC.notificationFullUrl;
        if (authorization != null && notificationUrl!=null) {
          try {
            new ApiRequest().apiRequestPostSendFCMNotificationOurServer(
                url: notificationUrl,
                bodyData: requestBody,
                isLoader: false,
                authorization: authorization)
                .then((response) {
                  print("$response");
            });
          } catch (e) {
            print(e);
          }
        }
      });

    } catch (e) {
      print(e);
      return "";
    }
    return Future.value("Done");
  }

  //Join group
  Future<dynamic> joinChatGroupFireBase({Key key, groupId, user}) async {
    //Check group id is created or not
    if (groupId != null) {
      try {
       var documentDetails =  await Firestore.instance
            .collection("user_groups")
            .document(groupId['gId']).get();
       //Check user already added in group
       //Yes exist
       if(documentDetails!=null && documentDetails.data!=null){

         // Map<String, String> inboxMap = new Map();
         List listData = documentDetails.data['usersDetails'];
         List listDataNew = new List();
         bool isAdded = false;
         for (var rowData in listData) {
           if (rowData != null && rowData['id'] == user.documentID) {
             try {
               rowData['isRequestNotAccepted'] = false;
             } catch (e) {
               print(e);
             }
             isAdded = true;
             listDataNew.add(rowData);
             print("firebase error $rowData");
           } else {
             listDataNew.add(rowData);
             print("firebase error $rowData");
           }
         }
         //if user not joiend group
         if(!isAdded && user.documentID!=null){
           var rowDataTemp = {"name":"","imageUrl":null,"pushToken":null,"id":user.documentID,"isRequestNotAccepted":false};
           listDataNew.add(rowDataTemp);
           print("firebase error $rowDataTemp");
           try {
             await Firestore.instance
                 .collection("user_groups")
                 .document(groupId['gId'])
                 .updateData(
                 {"usersDetails": FieldValue.arrayUnion(listDataNew)});

           } catch (e) {
             print(e);
           }
         }
         else {
           try {
             await Firestore.instance
                 .collection("user_groups")
                 .document(groupId['gId'])
                 .updateData(
                 {"usersDetails": listDataNew});
           } catch (e) {
             print(e);
           }
         }
         print("firebase error $documentDetails");

       }
       //Not added and add new user when it join
       else{
         await Firestore.instance
             .collection("user_groups")
             .document(groupId['gId'])
             .updateData({
           "usersDetails": FieldValue.arrayUnion([
             {
               "name": user.firstName != null ? user.firstName : "",
               "id": user.documentID,
               "imageUrl": user.imageUrl,
               "pushToken": user.fcmToken,
               "isRequestNotAccepted": false,
             }
           ])
         });
       }

       /*await Firestore.instance
           .collection("user_groups")
           .document(groupId['gId'])
           .updateData({
         "usersDetails": FieldValue.arrayUnion([
           {
             "name": user.firstName != null ? user.firstName : "",
             "id": user.documentID,
             "imageUrl": user.imageUrl,
             "pushToken": user.fcmToken,
             "isRequestNotAccepted": false,
           }
         ])
       });*/

        try{
        //Update group in in box
        var uId = groupId['gId'];
        String selfUid = user.documentID;
        ChatGroups mChatGroups =
            new ChatGroups(name: groupId['name'], image: groupId['name']);
        await inboxUpdateGroupJoinStatusFireBase(
            selfUid: selfUid,
            uId: uId,
            chatGroup: mChatGroups,
            isJoinGroup: true,
            isFromGroup: true);
      }
      catch (e) {
        // TODO
        print("firebase error $e");
      }
        return true;
      } on Exception catch (e) {
        // TODO
        print("firebase error $e");
        return false;
      }
    } else {
      return false;
    }
  }

  //left group
  Future<dynamic> leftChatGroupFireBase({Key key, String groupId, user}) async {
    //Check group id is created or not
    if (groupId != null) {
      try {
        try {
          //Left group
          var chatId = groupId;
          String selfUid = user.documentID;
          await inboxUpdateGroupJoinStatusFireBase(
              selfUid: selfUid,
              uId: chatId,
              isJoinGroup: false,
              isFromGroup: true);
        } catch (e) {
          // TODO
          print("firebase error $e");
        }
        final QuerySnapshot result = await Firestore.instance
            .collection('user_groups')
            .where('gId', isEqualTo: groupId)
            .getDocuments();
        final List<DocumentSnapshot> documents = result.documents;
        if (documents.length > 0) {
          // Map<String, String> inboxMap = new Map();
          List listData = documents[0].data['usersDetails'];
          List listDataNew = new List();
          for (var rowData in listData) {
            if (rowData != null && rowData['id'] == user.documentID) {
              print("firebase error $rowData");
            } else {
              listDataNew.add(rowData);
              print("firebase error $rowData");
            }
          }
          await Firestore.instance
              .collection("user_groups")
              .document(groupId)
              .updateData({"usersDetails": listDataNew});
          print("firebase error $documents");
        }
        return "";
      } on Exception catch (e) {
        // TODO
        print("firebase error $e");
        return "";
      }
    } else {
      return "";
    }
  }


  //left group
  Future<dynamic> setBaseUrl({Key key,String url}) async {
    //Check group id is created or not
    ConstantC.baseUrl = url;
        return true;
  }
  Future<dynamic> setNotificationUrl({Key key,String url}) async {
    //Check group id is created or not
    ConstantC.notificationFullUrl = url;
    return true;
  }
}
