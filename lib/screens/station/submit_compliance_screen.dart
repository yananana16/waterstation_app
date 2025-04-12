import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'displayingStatus.dart'; // Import the home screen

class SubmitCompliancePage extends StatefulWidget {
  const SubmitCompliancePage({super.key});

  @override
  _SubmitCompliancePageState createState() => _SubmitCompliancePageState();
}

class _SubmitCompliancePageState extends State<SubmitCompliancePage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Map<String, Uint8List?> selectedFiles = {};
  Map<String, String?> selectedFileNames = {};
  Map<String, String?> uploadedUrls = {};
  String? customUID;

  final Map<String, Map<String, String>> documentLabels = {
  'finished_bacteriological': {
    'label': 'Finished Product - Bacteriological',
    'time': 'Every Month',
  },
  'source_bacteriological': {
    'label': 'Source/Deep Well - Bacteriological',
    'time': 'Every 6 Months',
  },
  'source_physical_chemical': {
    'label': 'Source/Deep Well - Physical-Chemical',
    'time': 'Every 6 Months',
  },
  'finished_physical_chemical': {
    'label': 'Finished Product - Physical-Chemical',
    'time': 'Every 6 Months',
  },
  'business_permit': {
    'label': 'Business Permit (BPLO)',
    'time': 'Every 20th of January',
  },
  'dti_cert': {
    'label': 'DTI Certification',
    'time': 'Once',
  },
  'municipal_clearance': {
    'label': 'Municipal Environment and Natural Resources',
    'time': 'Once',
  },
  'retail_plan': {
    'label': 'Plan of the Retail Water Station',
    'time': 'Once',
  },
  'drinking_site_clearance': {
    'label': 'Drinking Water Site Clearance (Local Health Officer)',
    'time': 'Once',
  },
};


  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    String uid = auth.currentUser!.uid;
    DocumentSnapshot userDoc = await firestore.collection('users').doc(uid).get();

    if (userDoc.exists) {
      setState(() {
        customUID = userDoc['customUID'];
      });
      fetchUserComplianceFiles();
    }
  }

  Future<void> pickFile(String category) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        selectedFiles[category] = result.files.single.bytes;
        selectedFileNames[category] = result.files.single.name;
      });
    }
  }

  Future<void> uploadAllFiles() async {
    if (customUID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Custom UID not found.')),
      );
      return;
    }

    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one file.')),
      );
      return;
    }

    String uid = auth.currentUser!.uid;
    Map<String, String> newUploadedUrls = {};

    List<Future<void>> uploadTasks = selectedFiles.keys.map((category) async {
      String? fileUrl = await uploadFile(category);
      if (fileUrl != null) {
        newUploadedUrls[category] = fileUrl;
      }
    }).toList();

    await Future.wait(uploadTasks);

    await firestore.collection('compliance_uploads').doc(uid).set(
      newUploadedUrls,
      SetOptions(merge: true),
    );

    setState(() {
      uploadedUrls.addAll(newUploadedUrls);
      selectedFiles.clear();
      selectedFileNames.clear();
    });

    await checkAndUpdateApprovalStatus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('All files uploaded successfully!')),
    );
  }

  Future<String?> uploadFile(String category) async {
    if (selectedFiles[category] == null) return null;

    try {
      String fileName = selectedFileNames[category]!;
      String fileExtension = fileName.split('.').last;
      String storageFileName = "${customUID}_$category.$fileExtension";
      String storagePath = 'uploads/$customUID/$storageFileName';

      await deleteOldFile(customUID!, category);

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

  Future<void> deleteOldFile(String customUID, String category) async {
    try {
      String uid = auth.currentUser!.uid;
      DocumentSnapshot doc = await firestore.collection('compliance_uploads').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        String? existingFileUrl = (doc.data() as Map<String, dynamic>)[category];

        if (existingFileUrl != null) {
          Uri uri = Uri.parse(existingFileUrl);
          String fileName = uri.pathSegments.last;
          String filePath = 'uploads/$customUID/$fileName';

          await supabase.storage.from('compliance_docs').remove([filePath]);
        }
      }
    } catch (e) {
      print("Error deleting old file: $e");
    }
  }

  Future<void> fetchUserComplianceFiles() async {
    String uid = auth.currentUser!.uid;
    DocumentSnapshot doc = await firestore.collection('compliance_uploads').doc(uid).get();

    if (doc.exists) {
      setState(() {
        uploadedUrls = Map<String, String>.from(doc.data() as Map);
      });
    }
  }

  Future<void> checkAndUpdateApprovalStatus() async {
    if (customUID == null) return;

    String uid = auth.currentUser!.uid;
    DocumentSnapshot doc = await firestore.collection('compliance_uploads').doc(uid).get();

    if (!doc.exists) return;

    Map<String, dynamic> uploadedDocs = doc.data() as Map<String, dynamic>;

    bool allUploaded = documentLabels.keys.every((category) => uploadedDocs.containsKey(category));

    if (allUploaded) {
      await firestore.collection('users').doc(uid).update({'status': 'pending_approval'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All documents submitted! Status updated to Pending Approval.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Submit Compliance Documents'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DisplayStatusScreen()),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: documentLabels.keys.map((category) => complianceUploadCard(category)).toList(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: uploadAllFiles,
              icon: Icon(Icons.upload),
              label: Text('Upload All'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget complianceUploadCard(String category) {
  return Card(
    elevation: 4,
    margin: EdgeInsets.symmetric(vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            documentLabels[category]?['label'] ?? 'Unknown Label',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            'Time: ${documentLabels[category]?['time'] ?? 'Unknown Time'}',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          if (selectedFileNames[category] != null)
            Text(
              "Selected: ${selectedFileNames[category]!}",
              style: TextStyle(fontSize: 14, color: Colors.blue),
            ),
          if (uploadedUrls[category] != null)
            Text(
              '✔ Submitted',
              style: TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(Icons.attach_file, color: Colors.blueAccent),
              onPressed: () => pickFile(category),
            ),
          ),
        ],
      ),
    ),
  );
}

}
