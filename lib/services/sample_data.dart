import '../models/job.dart';

// TEMPORARY: fake jobs to build the screen with. Removed in Lesson 5.
List<Job> sampleJobs() {
  final now = DateTime.now();

  return [
    Job(
      id: 'sample1',
      companyId: 'sample',
      companyName: 'Stripe',
      title: 'Software Engineer',
      role: 'Engineering',
      location: 'Bengaluru, India',
      mode: 'Hybrid',
      description: 'About the role:\nBuild payment APIs used by millions of businesses.\n\n'
          'Requirements:\n• 2+ years with Java or Go\n• Good problem-solving skills',
      url: 'https://example.com',
      postedDate: now.subtract(const Duration(days: 2)),
    ),
    Job(
      id: 'sample2',
      companyId: 'sample',
      companyName: 'Netflix',
      title: 'Data Analyst',
      role: 'Analytics',
      location: 'Anywhere in India',
      mode: 'Remote',
      description: 'About the role:\nHelp teams make decisions using data.\n\n'
          'Requirements:\n• SQL and Python\n• Experience with dashboards',
      url: 'https://example.com',
      postedDate: now.subtract(const Duration(days: 5)),
    ),
    Job(
      id: 'sample3',
      companyId: 'sample',
      companyName: 'Notion',
      title: 'Product Designer',
      role: 'Design',
      location: 'Mumbai, India',
      mode: 'On-site',
      description: 'About the role:\nDesign simple, beautiful features.\n\n'
          'Requirements:\n• A strong portfolio\n• Figma skills',
      url: 'https://example.com',
      postedDate: now.subtract(const Duration(days: 1)),
    ),
    Job(
      id: 'sample4',
      companyId: 'sample',
      companyName: 'NVIDIA',
      title: 'Machine Learning Intern',
      role: 'Research',
      location: 'Pune, India',
      mode: 'On-site',
      description: 'About the role:\n6-month internship with the AI team.\n\n'
          'Requirements:\n• Final-year student\n• Python and PyTorch basics',
      url: 'https://example.com',
      postedDate: now.subtract(const Duration(days: 10)),
    ),
    Job(
      id: 'sample5',
      companyId: 'sample',
      companyName: 'Stripe',
      title: 'Support Specialist',
      role: 'Customer Success',
      location: 'Hyderabad, India',
      mode: 'Remote',
      description: 'About the role:\nHelp customers solve problems quickly.\n\n'
          'Requirements:\n• Clear communication\n• Fluent English',
      url: 'https://example.com',
      postedDate: now.subtract(const Duration(days: 3)),
    ),
  ];
}