import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_controller.dart';
import '../../ui/screens/home/home_screen.dart';
import 'company_create_screen.dart';

class CompanyListScreen extends StatelessWidget {
  const CompanyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final companies = app.companies;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a company'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CompanyCreateScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: companies.isEmpty
            ? _emptyState(context)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: companies.length,
                itemBuilder: (context, index) {
                  final company = companies[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(company.name),
                      subtitle: Text('Code: ${company.companyCode}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await app.setActiveCompany(company);
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CompanyCreateScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create company'),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No companies yet. Create your first company to continue.'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Create company'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CompanyCreateScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
