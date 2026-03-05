import SwiftUI

struct CourseFilterView: View {
    let courses: [String]
    @Binding var selectedCourse: String

    var body: some View {
        Picker("Course", selection: $selectedCourse) {
            ForEach(courses, id: \.self) { course in
                Text(course).tag(course)
            }
        }
        .pickerStyle(.menu)
    }
}
