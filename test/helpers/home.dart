import 'package:zolt/features/home/home_screen.dart';

/// Opens the home screen on its project list rather than on Home, for
/// tests about the list.
final startOnProjects = homeSectionProvider.overrideWith(_ProjectsFirst.new);

class _ProjectsFirst extends HomeSectionNotifier {
  @override
  HomeSection build() => HomeSection.projects;
}
