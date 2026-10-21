import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company.dart';
import '../models/job.dart';
import 'account.dart';

class StorageService {
  static const String _companiesKey = 'companies';
  static const String _jobsKey = 'jobs';

  // ---------- COMPANIES ----------
  static Future<void> saveCompanies(List<Company> companies) async {
    final prefs = await SharedPreferences.getInstance();
    final p = await Account.prefix();
    final text = jsonEncode(companies.map((c) => c.toJson()).toList());
    await prefs.setString('$p$_companiesKey', text);
  }

  static Future<List<Company>> loadCompanies() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final p = await Account.prefix();
    final text = prefs.getString('$p$_companiesKey');
    if (text == null) return [];
    final List decoded = jsonDecode(text);
    return decoded.map((item) => Company.fromJson(item)).toList();
  }

  // ---------- JOBS ----------
  static Future<void> saveJobs(List<Job> jobs) async {
    final prefs = await SharedPreferences.getInstance();
    final p = await Account.prefix();
    final text = jsonEncode(jobs.map((j) => j.toJson()).toList());
    await prefs.setString('$p$_jobsKey', text);
  }

  static Future<List<Job>> loadJobs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final p = await Account.prefix();
    final text = prefs.getString('$p$_jobsKey');
    if (text == null) return [];
    final List decoded = jsonDecode(text);
    return decoded.map((item) => Job.fromJson(item)).toList();
  }

  // ---------- RESET ALL (only the signed-in account's data) ----------
  static Future<void> clearAll() => Account.clearActiveData();
}