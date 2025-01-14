import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/attendance_models.dart';
import '../models/dummy.dart';
import '../models/dummy.dart';
import '../models/dummy.dart';
import '../models/user_model.dart' as user_model;

class APIs {
  static FirebaseAuth auth = FirebaseAuth.instance;
  static FirebaseFirestore firestore = FirebaseFirestore.instance;
  static FirebaseStorage storage = FirebaseStorage.instance;
//auth

  static Future<void> login(String email, String password) async {
    try {
      final UserCredential userCredential = await auth
          .signInWithEmailAndPassword(email: email, password: password);
      await fetchUserDataFromFirestore(userCredential);
      // if (userCredential.user!.emailVerified) {
      //   fetchUserDataFromFirestore(userCredential);
      // } else {
      //   throw 'Email not yet verified, check your mail';
      // }
    } on FirebaseAuthException catch (e) {
      // Handle registration errors
      print('Registration error: $e');
      if (e.code == 'unknown') {
        throw (' kindly check your internet connection');
      }
      throw (' ${e.message}');
    } catch (error) {
      throw (' ${error.toString()}');
    }
  }

  static late user_model.User userInfo;
  static UserData? academicRecords;
  static Future<void> fetchUserDataFromFirestore(
      UserCredential userCredential) async {
    final user = userCredential.user;
    final String userUID = user!.uid;

    DocumentSnapshot snapshot =
        await firestore.collection('users').doc(userUID).get();
    if (snapshot.exists) {
      Map<String, dynamic> userData = snapshot.data() as Map<String, dynamic>;
      print(userData);
      final user_model.User userDataInfo = user_model.User.fromJson(userData);
      userInfo = userDataInfo;
      // academicRecords = DUMMY.dummyAcademicRecords.last;
      print("done");
    } else {
      throw "User Details not found, kindly contact support.";
    }

    //
  }

  static Future<void> register(String name, String email, String password,
      user_model.UserType userType) async {
    try {
      final UserCredential userCredential = await auth
          .createUserWithEmailAndPassword(email: email, password: password);
      await userCredential.user!.sendEmailVerification();
      final String userUID = userCredential.user!.uid;
      final Map<String, dynamic> userData = {
        'name': name,
        'email': email,
        'id': userUID,
        'userType': userType.toStringValue(),
        'phoneNumber': "",
        'userInfo': userType == user_model.UserType.student
            ? {"imgUrl": "", "matricNumber": ""}
            : null
      };
      await firestore.collection('users').doc(userUID).set(userData);
      final user_model.User userDataInfo = user_model.User.fromJson(userData);
      userInfo = userDataInfo;
      // academicRecords = DUMMY.dummyAcademicRecords.last;
      print("print registration done !");
      //  Navigator.pushAndRemoveUntil(
      //   context,
      //   MaterialPageRoute(builder: (_) => DashboardScreen()),
      //       (Route<dynamic> route) => false,
      // );
    } on FirebaseAuthException catch (e) {
      // Handle registration errors
      print('Registration error: $e');
      if (e.code == 'unknown') {
        throw ('Registration failed, kindly check your internet connection');
      } else {
        throw ('Registration failed, ${e.message}');
      }
    } catch (error) {
      print(error);
      throw ('Registration failed, $error');
    }
  }

  static Future<void> updateProfilePicture(
      BuildContext context, File file) async {
    print('started profile ');
    final ext = file.path.split('.').last;
    print('Extenson: ${ext}');
    final ref = storage.ref().child('profile_pictures/${userInfo.id}.$ext');
    try {
      await ref
          .putFile(file, SettableMetadata(contentType: 'image/${ext}'))
          .then((p0) {
        print('Date Transffered: ${p0.bytesTransferred / 1000} kb ');
      });
      userInfo.userInfo!.imgUrl = await ref.getDownloadURL();
      await updateUserInfo();
    } on FirebaseException catch (e) {
      // Handle registration errors
      print('Registration error: $e');
      if (e.code == 'unknown') {
        throw ('Registration failed, kindly check your internet connection');
      }
      throw 'Upload failed';
    } catch (error) {
      throw 'Upload failed';
    }
  }

  static Future<String> getImgUrl(File file) async {
    print('started capture img ');
    final ext = file.path.split('.').last;
    print('Extenson: ${ext}');
    final ref = storage.ref().child('captured_images/${userInfo.id}.$ext');
    try {
      await ref
          .putFile(file, SettableMetadata(contentType: 'image/${ext}'))
          .then((p0) {
        print('Date Transffered: ${p0.bytesTransferred / 1000} kb ');
      });
      String url = await ref.getDownloadURL();
      return url;
    } on FirebaseException catch (e) {
      // Handle registration errors
      print('Registration error: $e');
      if (e.code == 'unknown') {
        throw ('Operation failed, kindly check your internet connection');
      }
      throw 'Image Processing failed';
    } catch (error) {
      throw 'Image Processing failed';
    }
  }

  static Future<void> updateUserInfo() async {
    try {
      await firestore
          .collection('users')
          .doc(userInfo.id)
          .update(userInfo.toJson());
    } on FirebaseException catch (e) {
      // Handle registration errors
      print('Registration error: $e');
      if (e.code == 'unknown') {
        throw ('Registration failed, kindly check your internet connection');
      }
      throw 'Upload failed';
    } catch (error) {
      throw 'Upload failed';
    }
  }

  static Future<DetectionStatus> sendRecognitionRequest(File file) async {
    try {
      final Dio dio = new Dio();

      String url2 = await getImgUrl(file);
      final data = {"url1": userInfo.userInfo!.imgUrl, "url2": url2};
      final response = await http.post(
        Uri.parse('http://192.168.168.144:5050/recognize'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        body: json.encode(data),
      ); //dnb7nyl
      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);

        if (responseData['data'] == null) {
          throw ('Server error occurred in recognizing face');
        } else {
          switch (responseData['data']) {
            case 0:
              return DetectionStatus.noFace;

            case 1:
              return DetectionStatus.fail;

            case 2:
              return DetectionStatus.success;

            default:
              return DetectionStatus.noFace;
          }
        }
      } else {
        throw ('${response.statusCode} error');
      }
    } catch (error) {
      throw ('Error decoding JSON: $error');
    }
  }

//courses
  static Stream<DocumentSnapshot<Map<String, dynamic>>> fetchAcademicData() {
    String userType = userInfo.userType.name.toLowerCase();

    // Reference to the user's document in the records collection

    return firestore
        .collection('records')
        .doc(userType)
        .collection(userType == 'staff' ? 'staffs' : 'students')
        .doc(userInfo.id)
        .snapshots();
  }

  static Future<void> changeStudentAttendance(
      Session session,
      Semester semester,
      Course course,
      Attendance attendance,
      StudentData studentData,
      bool status) async {
    try {
      int sessionIndex = academicRecords!.sessions.indexWhere(
        (userSession) => userSession.sessionYear == session.sessionYear,
      );
      if (sessionIndex != 1) {
        int semesterIndex =
            academicRecords!.sessions[sessionIndex].semesters.indexWhere(
          (userSemester) =>
              userSemester.semesterNumber == semester.semesterNumber,
        );
        if (semesterIndex != -1) {
          int courseIndex = academicRecords!
              .sessions[sessionIndex].semesters[semesterIndex].courses
              .indexWhere(
            (userCourse) => userCourse.courseId == course.courseId,
          );
          if (courseIndex != -1) {
            int attendanceIndex = academicRecords!.sessions[sessionIndex]
                .semesters[semesterIndex].courses[courseIndex].attendanceList
                .indexWhere(
              (atten) =>
                  atten.attendanceId == attendance.attendanceId &&
                  atten.verificationCode == attendance.verificationCode,
            );
            if (attendanceIndex != -1) {
              int studentIndex = academicRecords!
                  .sessions[sessionIndex]
                  .semesters[semesterIndex]
                  .courses[courseIndex]
                  .attendanceList[attendanceIndex]
                  .students
                  .indexWhere(
                      (stud) => stud.studentId == studentData.studentId);
              if (studentIndex != -1) {
                academicRecords!
                    .sessions[sessionIndex]
                    .semesters[semesterIndex]
                    .courses[courseIndex]
                    .attendanceList[attendanceIndex]
                    .students[studentIndex]
                    .isPresent = false;

                academicRecords!
                    .sessions[sessionIndex]
                    .semesters[semesterIndex]
                    .courses[courseIndex]
                    .attendanceList[attendanceIndex]
                    .students[studentIndex]
                    .isEligible = false;
                print("finished lecturer");
                await updateRecord(academicRecords!, userInfo)
                    .then((value) async {
                  String studentId = studentData.studentId;
                  DocumentSnapshot<Map<String, dynamic>> studentSnapshot =
                      await firestore.collection('users').doc(studentId).get();
                  if (studentSnapshot.exists) {
                    Map<String, dynamic> studentData = studentSnapshot.data()!;
                    final user_model.User studentBasicInfo =
                        user_model.User.fromJson(studentData);

                    String userType =
                        studentBasicInfo.userType.name.toLowerCase();
                    DocumentSnapshot<Map<String, dynamic>> studentRecord =
                        await firestore
                            .collection('records')
                            .doc(userType)
                            .collection(
                                userType == 'staff' ? 'staffs' : 'students')
                            .doc(studentId)
                            .get();
                    if (studentRecord.exists) {
                      Map<String, dynamic> studentData =
                          studentRecord.data()!['academicRecords'];
                      UserData student = UserData.fromJson(studentData);
                      student
                          .sessions[sessionIndex]
                          .semesters[semesterIndex]
                          .courses[courseIndex]
                          .attendanceList[attendanceIndex]
                          .students[studentIndex]
                          .isPresent = false;
                      student
                          .sessions[sessionIndex]
                          .semesters[semesterIndex]
                          .courses[courseIndex]
                          .attendanceList[attendanceIndex]
                          .students[studentIndex]
                          .isEligible = false;
                      await updateRecord(student, studentBasicInfo);
                      print("student done");
                    }
                  }
                });
              } else {
                "student not found";
              }
            } else {
              "attendance not found";
            }
          } else {
            "Course not found";
          }
        } else {
          throw "Semester not found";
        }
      } else {
        throw "Session not found";
      }
      print("removed done!");
    } catch (error) {
      rethrow;
    }
  }

  static Future<void> updateRecord(
      UserData academicRecords, user_model.User userInfo) async {
    try {
      // Reference to the user's document in the records collection
      String userType = userInfo.userType.name.toLowerCase();

      // Reference to the user's document in the records collection
      DocumentReference userDocRef = firestore
          .collection('records')
          .doc(userType)
          .collection(userType == 'staff' ? 'staffs' : 'students')
          .doc(userInfo.id);

      await userDocRef.set({'academicRecords': academicRecords.toJson()});

      print("Course registration added for a new user");

      // Get the user's document
    } catch (error) {
      // Handle errors
      print('Error registering courses: $error');
      rethrow;
    }
  }

//
//attendance
  static Future<void> addAttendanceToAcademicRecords(Session session,
      Semester semester, Course course, Attendance newAttendance) async {
    // Ensure academicRecords is not null
    if (academicRecords != null) {
      // Create a copy of academicRecords
      UserData updatedAcademicRecords = academicRecords!;

      // Find the target session
      int sessionIndex = updatedAcademicRecords.sessions.indexWhere(
        (userSession) => userSession.sessionYear == session.sessionYear,
      );

      if (sessionIndex != -1) {
        // Find the target semester
        int semesterIndex =
            updatedAcademicRecords.sessions[sessionIndex].semesters.indexWhere(
          (userSemester) =>
              userSemester.semesterNumber == semester.semesterNumber,
        );

        if (semesterIndex != -1) {
          // Find the target course
          int courseIndex = updatedAcademicRecords
              .sessions[sessionIndex].semesters[semesterIndex].courses
              .indexWhere(
            (userCourse) => userCourse.courseId == course.courseId,
          );

          if (courseIndex != -1) {
            // Add the newAttendance to the target course in the copied data
            updatedAcademicRecords.sessions[sessionIndex]
                .semesters[semesterIndex].courses[courseIndex].attendanceList
                .add(newAttendance);

            // Update the original academicRecords with the modified copy
            academicRecords = updatedAcademicRecords;
            await updateRecord(academicRecords!, userInfo);
            await addAttendanceToFilteredStudents(
                session, semester, course, newAttendance);
            print("Attendance added to academicRecords");
          } else {
            throw ("Course not found in academicRecords");
          }
        } else {
          throw ("Semester not found in academicRecords");
        }
      } else {
        throw ("Session not found in academicRecords");
      }
    } else {
      throw ("academicRecords is null");
    }
  }

  static Future<List<UserData>> getAllStudents() async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await firestore.collection('students').get();

      List<UserData> students = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return UserData.fromJson(data); // Assuming you have a Student class
      }).toList();

      return students;
    } catch (error) {
      throw ('Error getting students: $error');
    }
  }

  static Future<void> addAttendanceToFilteredStudents(
    Session session,
    Semester semester,
    Course course,
    Attendance newAttendance,
  ) async {
    try {
      // Fetch the filtered students
      List<UserData> filteredStudents =
          await getFilteredStudents(session, semester, course);

      // Update attendance for each student
      for (UserData student in filteredStudents) {
        // Find the target session
        int sessionIndex = student.sessions.indexWhere(
          (userSession) => userSession.sessionYear == session.sessionYear,
        );

        if (sessionIndex != -1) {
          // Find the target semester
          int semesterIndex =
              student.sessions[sessionIndex].semesters.indexWhere(
            (userSemester) =>
                userSemester.semesterNumber == semester.semesterNumber,
          );

          if (semesterIndex != -1) {
            // Find the target course
            int courseIndex = student
                .sessions[sessionIndex].semesters[semesterIndex].courses
                .indexWhere(
              (userCourse) => userCourse.courseId == course.courseId,
            );

            if (courseIndex != -1) {
              // Add the newAttendance to the target course in the student's data
              student.sessions[sessionIndex].semesters[semesterIndex]
                  .courses[courseIndex].attendanceList
                  .add(newAttendance);
            }
          }
        }
      }

      // Save the modified attendance back to Firestore for each student
      for (UserData student in filteredStudents) {
        await updateUsersRecord(
            user_model.UserType.student, student.studentId, student);
      }

      print('Attendance added to filtered students');
    } catch (error) {
      throw ('Error adding attendance to filtered students: $error');
    }
  }

  static updateUsersRecord(
      user_model.UserType type, String id, UserData record) async {
    String userType = type.name.toLowerCase();

    // Reference to the user's document in the records collection
    DocumentReference userDocRef = firestore
        .collection('records')
        .doc(userType)
        .collection(userType == 'staff' ? 'staffs' : 'students')
        .doc(id);

    await userDocRef.set({'academicRecords': record.toJson()});
  }

  static Future<List<UserData>> getFilteredStudents(
    Session session,
    Semester semester,
    Course course,
  ) async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot = await firestore
          .collection('records')
          .doc("student")
          .collection("students")
          .get();

      List<UserData> students = [];

      for (QueryDocumentSnapshot<Map<String, dynamic>> doc
          in querySnapshot.docs) {
        Map<String, dynamic> userData = doc.data();
        print("User data${userData}");
        UserData student = UserData.fromJson(userData['academicRecords']);

        if (isStudentEnrolled(student, session, semester, course) &&
            student.sessions.any((s) => s.semesters.any((sem) =>
                sem.courses.any((c) => c.courseId == course.courseId)))) {
          students.add(student);
        }
      }

      return students;
    } catch (error) {
      throw ('Error getting students: $error');
    }
  }

  static bool isStudentEnrolled(
    UserData student,
    Session session,
    Semester semester,
    Course course,
  ) {
    // Replace this with your logic to check if the student is enrolled
    return student.sessions.any((s) =>
        s.sessionYear == session.sessionYear &&
        s.semesters.any((sem) =>
            sem.semesterNumber == semester.semesterNumber &&
            sem.courses.any((c) => c.courseId == course.courseId)));
  }

  static bool studentIsEnrolledInCourse(UserData student, Course course) {
    // Replace this with your logic to check if the student is enrolled in the course
    return course.attendanceList.any((attendance) => student.sessions.any((s) =>
        s.semesters.any(
            (sem) => sem.courses.any((c) => c.courseId == course.courseId))));
  }

  static Future<Position> determinePosition() async {
    LocationPermission permission;
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        return Future.error('Location Not Available');
      }
    }
    return await Geolocator.getCurrentPosition();
  }

  static Future<void> updateStudentAttendanceAndLecturerList(
    UserData student,
    Session session,
    Semester semester,
    Course course,
    Attendance newAttendance,
    bool status,
    StudentData studentData,
  ) async {
    print("started uploading to staff ans tudent");
    try {
      // Check if the verification code already exists
      int sessionIndex = student.sessions.indexWhere(
        (userSession) => userSession.sessionYear == session.sessionYear,
      );

      if (sessionIndex != -1) {
        int semesterIndex = student.sessions[sessionIndex].semesters.indexWhere(
          (userSemester) =>
              userSemester.semesterNumber == semester.semesterNumber,
        );

        if (semesterIndex != -1) {
          int courseIndex = student
              .sessions[sessionIndex].semesters[semesterIndex].courses
              .indexWhere(
            (userCourse) => userCourse.courseId == course.courseId,
          );

          if (courseIndex != -1) {
            // Find the attendance index with matching attendanceId and verificationCode
            int attendanceIndex = student.sessions[sessionIndex]
                .semesters[semesterIndex].courses[courseIndex].attendanceList
                .indexWhere(
              (atten) =>
                  atten.attendanceId == newAttendance.attendanceId &&
                  atten.verificationCode == newAttendance.verificationCode,
            );

            if (attendanceIndex != -1) {
              // Check if the student is already present in the attendance list
              int? studentIndex = student
                  .sessions[sessionIndex]
                  .semesters[semesterIndex]
                  .courses[courseIndex]
                  .attendanceList[attendanceIndex]
                  .students
                  ?.indexWhere(
                      (stud) => stud.studentId == studentData.studentId);

              if (studentIndex == -1 || studentIndex == null) {
                // If the student is not present, add the StudentData to the list
                student
                    .sessions[sessionIndex]
                    .semesters[semesterIndex]
                    .courses[courseIndex]
                    .attendanceList[attendanceIndex]
                    .students
                    ?.add(StudentData(
                  studentId: studentData.studentId,
                  matricNumber: studentData.matricNumber,
                  studentName: studentData.studentName,
                  isPresent: status,
                  isEligible: true,
                ));
              }
            }
            String studentId = studentData.studentId;
            DocumentSnapshot<Map<String, dynamic>> studentSnapshot =
                await firestore.collection('users').doc(studentId).get();
            if (studentSnapshot.exists) {
              Map<String, dynamic> studentData = studentSnapshot.data()!;
              final user_model.User studentBasicInfo =
                  user_model.User.fromJson(studentData);
              await updateRecord(
                student,
                studentBasicInfo,
              );
              // Save the modified attendance back to Firestore for the student
            }
          }
        }
        print("started lecturer");
        // Find lecturer details
        String lecturerId = newAttendance.lecturerId;
        DocumentSnapshot<Map<String, dynamic>> lecturerSnapshot =
            await firestore.collection('users').doc(lecturerId).get();

        if (lecturerSnapshot.exists) {
          Map<String, dynamic> lecturerData = lecturerSnapshot.data()!;
          final user_model.User lecturerBasicInfo =
              user_model.User.fromJson(lecturerData);

          String userType = lecturerBasicInfo.userType.name.toLowerCase();

          // Reference to the user's document in the records collection

          DocumentSnapshot<Map<String, dynamic>> lecturerRecord =
              await firestore
                  .collection('records')
                  .doc(userType)
                  .collection(userType == 'staff' ? 'staffs' : 'students')
                  .doc(lecturerId)
                  .get();
          print(lecturerRecord.data()!);
          if (lecturerRecord.exists) {
            Map<String, dynamic> lecturerData =
                lecturerRecord.data()!['academicRecords'];

            UserData lecturer = UserData.fromJson(lecturerData);

            // Add the studentData to the lecturer's attendance list
            int lecturerSessionIndex = lecturer.sessions.indexWhere(
              (userSession) => userSession.sessionYear == session.sessionYear,
            );

            if (lecturerSessionIndex != -1) {
              int lecturerSemesterIndex =
                  lecturer.sessions[lecturerSessionIndex].semesters.indexWhere(
                (userSemester) =>
                    userSemester.semesterNumber == semester.semesterNumber,
              );

              if (lecturerSemesterIndex != -1) {
                int lecturerCourseIndex = lecturer
                    .sessions[lecturerSessionIndex]
                    .semesters[lecturerSemesterIndex]
                    .courses
                    .indexWhere(
                  (userCourse) => userCourse.courseId == course.courseId,
                );

                if (lecturerCourseIndex != -1) {
                  print(
                      " Check if the verification code already exists for the lecturer");
                  bool attendanceExists = lecturer
                      .sessions[lecturerSessionIndex]
                      .semesters[lecturerSemesterIndex]
                      .courses[lecturerCourseIndex]
                      .attendanceList
                      .any((attendance) =>
                          attendance.verificationCode ==
                          newAttendance.verificationCode);
                  if (!attendanceExists) {
                    print(
                        " If the attendance doesn't exist, add a new attendance record");
                    lecturer
                        .sessions[lecturerSessionIndex]
                        .semesters[lecturerSemesterIndex]
                        .courses[lecturerCourseIndex]
                        .attendanceList
                        .add(newAttendance);
                  }

                  print(
                      "Update the student data in the lecturer's attendance list");
                  int lecturerAttendanceIndex = lecturer
                      .sessions[lecturerSessionIndex]
                      .semesters[lecturerSemesterIndex]
                      .courses[lecturerCourseIndex]
                      .attendanceList
                      .indexWhere((attendance) =>
                          attendance.verificationCode ==
                              newAttendance.verificationCode &&
                          attendance.lecturerId == newAttendance.lecturerId);
                  if (lecturerAttendanceIndex != -1) {
                    print(
                        "Update the student data in the lecturer's attendance list");
                    int studentIndex = lecturer
                        .sessions[lecturerSessionIndex]
                        .semesters[lecturerSemesterIndex]
                        .courses[lecturerCourseIndex]
                        .attendanceList[lecturerAttendanceIndex]
                        .students
                        .indexWhere(
                      (stud) => stud.studentId == studentData.studentId,
                    );
                    if (studentIndex != -1) {
                      print("The student was found in the list");
                      print("Update the student's isPresent status");
                      lecturer
                          .sessions[lecturerSessionIndex]
                          .semesters[lecturerSemesterIndex]
                          .courses[lecturerCourseIndex]
                          .attendanceList[lecturerAttendanceIndex]
                          .students[studentIndex]
                          .isPresent = status;
                    } else {
                      print("The student was not found in the list");
                      print(
                          " Add the student to the list with the specified status");
                      lecturer
                          .sessions[lecturerSessionIndex]
                          .semesters[lecturerSemesterIndex]
                          .courses[lecturerCourseIndex]
                          .attendanceList[lecturerAttendanceIndex]
                          .students
                          .add(StudentData(
                        studentId: studentData.studentId,
                        matricNumber: studentData.matricNumber,
                        studentName: studentData.studentName,
                        isPresent: status,
                        isEligible: true,
                      ));
                    }
                  } else {
                    lecturer
                        .sessions[lecturerSessionIndex]
                        .semesters[lecturerSemesterIndex]
                        .courses[lecturerCourseIndex]
                        .attendanceList[lecturerAttendanceIndex]
                        .students
                        .add(StudentData(
                      studentId: studentData.studentId,
                      matricNumber: studentData.matricNumber,
                      studentName: studentData.studentName,
                      isPresent: status,
                      isEligible: true,
                    ));
                  }

                  // Save the modified attendance back to Firestore for the lecturer
                } else {
                  throw "Course not found";
                }
              } else {
                throw "Semester not found";
              }
            } else {
              throw "Session not found";
            }
            await updateRecord(
              lecturer,
              lecturerBasicInfo,
            );
          }

          print('Attendance updated for student and lecturer');
        }
      }
    } catch (error) {
      print(error);
      throw ('Error updating attendance: $error');
    }
  }

  static Future<void> logOut() async {
    academicRecords = null;
    await auth.signOut();
    // await GoogleSignIn().signOut();
  }
}

enum DetectionStatus { noFace, fail, success }
