import 'dart:convert'; // gives jsonEncode / jsonDecode
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company.dart';
import '../models/job.dart';

class StorageService {
  // Keys = page names in our "notebook"
  static const String _companiesKey = 'companies';
  static const String _jobsKey = 'jobs';

  // ---------- COMPANIES ----------
  static Future<void> saveCompanies(List<Company> companies) async {
    final prefs = await SharedPreferences.getInstance(); // open notebook
    final mapList = companies.map((c) => c.toJson()).toList(); // pack each
    final text = jsonEncode(mapList);                    // list → text
    await prefs.setString(_companiesKey, text);          // write page
  }

  static Future<List<Company>> loadCompanies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();   
    final text = prefs.getString(_companiesKey);         // read page
    if (text == null) return [];                         // nothing saved yet
    final List decoded = jsonDecode(text);               // text → list
    return decoded.map((item) => Company.fromJson(item)).toList(); // unpack
  }

  // ---------- JOBS ----------
  static Future<void> saveJobs(List<Job> jobs) async {
    final prefs = await SharedPreferences.getInstance();
    final text = jsonEncode(jobs.map((j) => j.toJson()).toList());
    await prefs.setString(_jobsKey, text);
  }

  static Future<List<Job>> loadJobs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();   
    final text = prefs.getString(_jobsKey);
    if (text == null) return [];
    final List decoded = jsonDecode(text);
    return decoded.map((item) => Job.fromJson(item)).toList();
  }

  // ---------- RESET ALL (for Settings) ----------
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // tear out every page
  }
}