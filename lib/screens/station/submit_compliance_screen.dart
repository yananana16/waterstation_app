import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart'; // Import the home screen
import 'displayingStatus.dart'; // Import DisplayStatusScreen
import '../login_screen.dart'; // <-- Add this import (adjust path as needed)

class SubmitCompliancePage extends StatefulWidget {
  const SubmitCompliancePage({super.key});

  @override
  _SubmitCompliancePageState createState() => _SubmitCompliancePageState();
}

class _SubmitCompliancePageState extends State<SubmitCompliancePage> {
  final SupabaseClient supabase = Supabase.instance.client; // Supabase connection
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Map<String, Uint8List?> selectedFiles = {};
  Map<String, String?> selectedFileNames = {};
  Map<String, String?> uploadedUrls = {};
  String? stationOwnerDocID; // Store the document ID of the station owner
  String? membershipType; // Add this to store membership type
  String? stationStatus; // Add this to store the station status
  bool isTermsAccepted = false; // Track terms acceptance

  final Map<String, Map<String, String>> documentLabels = {
    'business_permit': {
      'label': 'Business Permit',
      'time': '',
    },
    'sanitary_permit': {
      'label': 'Sanitary Permit',
      'time': '',
    },
    'finished_bacteriological': {
      'label': 'Finished Product - Bacteriological',
      'time': '',
    },
    'source_bacteriological': {
      'label': 'Source/Deep Well - Bacteriological',
      'time': '',
    },
    'source_physical_chemical': {
      'label': 'Source/Deep Well - Physical-Chemical',
      'time': '',
    },
    'finished_physical_chemical': {
      'label': 'Finished Product - Physical-Chemical',
      'time': '',
    },
    'certificate_of_association': {
      'label': 'Certificate of Association',
      'time': '',
    },
  };

  @override
  void initState() {
    super.initState();
    fetchStationOwnerData();
  }

  Future<void> fetchStationOwnerData() async {
    String uid = auth.currentUser!.uid;
    QuerySnapshot querySnapshot = await firestore
        .collection('station_owners')
        .where('userId', isEqualTo: uid) // Match the userId field
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      setState(() {
        stationOwnerDocID = querySnapshot.docs.first.id; // Get the document ID
        membershipType = querySnapshot.docs.first['membership'] as String?;
        stationStatus = querySnapshot.docs.first['status'] as String?; // Get status
      });
      fetchUserComplianceFiles();
    }
  }

  Future<void> pickFile(String category) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);

    if (result != null && result.files.single.bytes != null) {
      String fileName = result.files.single.name.toLowerCase();
      // Allowed extensions
      final allowedExtensions = ['pdf', 'jpeg', 'jpg', 'png', 'doc', 'docx'];
      String fileExtension = fileName.split('.').last;
      if (!allowedExtensions.contains(fileExtension)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Only PDF, JPEG, PNG, JPG, and Word files are allowed.')),
        );
        return;
      }
      setState(() {
        selectedFiles[category] = result.files.single.bytes;
        selectedFileNames[category] = result.files.single.name;
      });
    }
  }

  Future<void> uploadAllFiles() async {
    final docKeys = getFilteredDocumentKeys();
    // Require all files to be selected
    if (!docKeys.every((key) => selectedFileNames[key] != null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select all required files before uploading.')),
      );
      return;
    }
    if (!isTermsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must accept the terms and conditions.')),
      );
      return;
    }

    if (stationOwnerDocID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Station owner data not found.')),
      );
      return;
    }

    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one file.')),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    Map<String, String> newUploadedUrls = {};
    Map<String, String> statusFields = {};

    List<Future<void>> uploadTasks = selectedFiles.keys.map((category) async {
      String? fileUrl = await uploadFile(category);
      if (fileUrl != null) {
        newUploadedUrls[category] = fileUrl;
        statusFields['${category}_status'] = 'pending'; // Insert status for each file/category
      }
    }).toList();

    await Future.wait(uploadTasks);

    // Add submission_date to the uploaded document
    newUploadedUrls['submission_date'] = DateTime.now().toIso8601String();

    // Merge file URLs and status fields
    final uploadData = {...newUploadedUrls, ...statusFields};

    await firestore.collection('compliance_uploads').doc(stationOwnerDocID).set(
      uploadData,
      SetOptions(merge: true),
    );

    setState(() {
      uploadedUrls.addAll(newUploadedUrls);
      selectedFiles.clear();
      selectedFileNames.clear();
      stationStatus = 'pending_approval'; // Update local status
    });

    // Immediately update status to pending_approval after successful upload
    await firestore.collection('station_owners').doc(stationOwnerDocID).update({'status': 'pending_approval'});

    // Hide loading dialog
    Navigator.of(context, rootNavigator: true).pop();

    // Directly navigate to DisplayStatusScreen (no success dialog)
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DisplayStatusScreen()),
      (route) => false,
    );
  }

  Future<String?> uploadFile(String category) async {
    if (selectedFiles[category] == null) return null;

    try {
      String fileName = selectedFileNames[category]!;
      String fileExtension = fileName.split('.').last;
      String storageFileName = "${stationOwnerDocID}_$category.$fileExtension";
      String storagePath = 'uploads/$stationOwnerDocID/$storageFileName';

      await deleteOldFile(category);

      await supabase.storage.from('compliance_docs').uploadBinary(
        storagePath,
        selectedFiles[category]!,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      return supabase.storage.from('compliance_docs').getPublicUrl(storagePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
      return null;
    }
  }

  Future<void> deleteOldFile(String category) async {
    try {
      if (stationOwnerDocID == null) return;

      DocumentSnapshot doc = await firestore.collection('compliance_uploads').doc(stationOwnerDocID).get();
      if (doc.exists && doc.data() != null) {
        String? existingFileUrl = (doc.data() as Map<String, dynamic>)[category];

        if (existingFileUrl != null) {
          Uri uri = Uri.parse(existingFileUrl);
          String fileName = uri.pathSegments.last;
          String filePath = 'uploads/$stationOwnerDocID/$fileName';

          await supabase.storage.from('compliance_docs').remove([filePath]);
        }
      }
    } catch (e) {
      print("Error deleting old file: $e");
    }
  }

  Future<void> fetchUserComplianceFiles() async {
    if (stationOwnerDocID == null) return;

    DocumentSnapshot doc = await firestore
        .collection('compliance_uploads')
        .doc(stationOwnerDocID)
        .get();

    if (doc.exists) {
      setState(() {
        uploadedUrls = Map<String, String>.from(doc.data() as Map);
      });
    }
  }

  Future<void> checkAndUpdateApprovalStatus() async {
    if (stationOwnerDocID == null) return;

    DocumentSnapshot doc = await firestore
        .collection('compliance_uploads')
        .doc(stationOwnerDocID)
        .get();

    if (!doc.exists) return;

    Map<String, dynamic> uploadedDocs = doc.data() as Map<String, dynamic>;

    bool allUploaded = documentLabels.keys.every((category) => uploadedDocs.containsKey(category));

    if (allUploaded) {
      await firestore.collection('station_owners').doc(stationOwnerDocID).update({'status': 'pending_approval'});

      setState(() {
        stationStatus = 'pending_approval'; // Update local status
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All documents submitted! Status updated to Pending Approval.')),
      );

      // Navigate to DisplayStatusScreen after upload and status update
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DisplayStatusScreen()),
          (route) => false,
        );
      });
    }
  }

  List<String> getFilteredDocumentKeys() {
    if (membershipType == 'new') {
      return [
        'business_permit',
        'sanitary_permit',
        'finished_bacteriological',
        'source_bacteriological',
        'source_physical_chemical',
        'finished_physical_chemical',
      ];
    }
    if (membershipType == 'existing') {
      return [
        'business_permit',
        'sanitary_permit',
        'finished_bacteriological',
        'source_bacteriological',
        'source_physical_chemical',
        'finished_physical_chemical',
        'certificate_of_association',
      ];
    }
    // fallback: show all
    return documentLabels.keys.toList();
  }

  @override
  Widget build(BuildContext context) {
    final docKeys = getFilteredDocumentKeys();
    // Check if all required files are selected
    final allRequiredSelected = docKeys.every((key) => selectedFileNames[key] != null);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue[900]),
          onPressed: () async {
            await Future.delayed(const Duration(milliseconds: 1500));
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
              (route) => false,
            );
          },
        ),
        title: Text(
          'Submit Compliance',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.blue[900],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Image.asset(
                'assets/illustration_submit.png',
                height: 140,
              ),
            ),
            if (stationStatus == 'pending_approval') // Show status banner
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top, color: Colors.orange[800]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your documents are under review. Status: Pending Verification.',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                children: docKeys.map((category) => complianceUploadCard(category)).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Terms and Conditions',
                  style: TextStyle(
                    color: Colors.blue[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "I certify that the documents I have submitted are true and correct. I understand that providing false information may lead to the denial or cancellation of my membership. I agree to the Terms and Conditions.",
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: isTermsAccepted,
                  onChanged: (value) {
                    setState(() {
                      isTermsAccepted = value ?? false;
                    });
                  },
                ),
                SizedBox(width: 4),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                      children: [
                        TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms and Conditions.',
                          style: TextStyle(
                            color: Colors.blue[700],
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (context) => _TermsBottomSheet(),
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (isTermsAccepted && allRequiredSelected) ? uploadAllFiles : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isTermsAccepted && allRequiredSelected) ? Colors.blue[700] : Colors.grey[400],
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Text(
                  'Upload All Files',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget complianceUploadCard(String category) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.4), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => pickFile(category),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Checkbox(
                value: selectedFileNames[category] != null,
                onChanged: (_) => pickFile(category),
                activeColor: Colors.blue[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: BorderSide(color: Colors.blue[700]!, width: 2),
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  documentLabels[category]?['label'] ?? category,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.attach_file, color: Colors.blue[700], size: 20),
                onPressed: () => pickFile(category),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Terms and Conditions Bottom Sheet Widget ---
class _TermsBottomSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                "Terms and Conditions",
                style: TextStyle(
                  color: Colors.blue[900],
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 16),
              Text(
                "Declaration and Agreement for Document Submission",
                style: TextStyle(
                  color: Colors.blue[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "By submitting the required documents to register as a member of the Iloilo City Water Plant and Water Refilling Stations Association, I hereby declare and agree to the following terms:",
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              SizedBox(height: 12),
              _termsList(),
              SizedBox(height: 16),
              Text(
                "By ticking the checkbox and submitting my application, I confirm that I have read, understood, and agreed to the above terms and conditions.",
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text("Close", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _termsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _termsItem("1. I affirm that all the documents submitted are complete, accurate, and true to the best of my knowledge."),
        _termsItem("2. I understand that the submitted documents are subject to verification by the Association and relevant government agencies."),
        _termsItem("3. I acknowledge that any falsification, misrepresentation, or omission of information may result in the denial or revocation of my membership."),
        _termsItem("4. I agree to comply with the rules, guidelines, and regulatory requirements set by the Association and governing authorities."),
        _termsItem("5. I authorize the Iloilo City Water Plant and Water Refilling Stations Association to store and use my submitted documents for evaluation and record-keeping purposes in accordance with applicable data privacy laws."),
      ],
    );
  }

  Widget _termsItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: Colors.black87),
      ),
    );
  }
}
