import SwiftUI

struct AuthSheetView: View {
  @ObservedObject var model: AppModel
  @Environment(\.dismiss) private var dismiss

  private var modeBinding: Binding<String> {
    Binding(
      get: { model.authMode.id },
      set: { model.authMode = $0 == AuthMode.signUp.id ? .signUp : .signIn }
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        Text(model.authMode.title)
          .font(.title3)
          .fontWeight(.semibold)
        Spacer()
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
        }
        .buttonStyle(.borderless)
      }

      Picker("Mode", selection: modeBinding) {
        Text("登录").tag(AuthMode.signIn.id)
        Text("注册").tag(AuthMode.signUp.id)
      }
      .pickerStyle(.segmented)

      Form {
        TextField("Email", text: $model.authEmail)
        SecureField("Password", text: $model.authPassword)
        if model.authMode == .signUp {
          TextField("Name", text: $model.authName)
        }
      }
      .formStyle(.grouped)

      if !model.authError.isEmpty {
        Text(model.authError)
          .foregroundStyle(.red)
      }

      HStack {
        Text("Auth requests go through the Sealos gateway.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Cancel") {
          dismiss()
        }
        Button(model.authMode == .signUp ? "Register" : "Sign In") {
          Task { await model.signInOrSignUp() }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(model.authSubmitting)
      }
    }
    .padding(22)
    .frame(width: 440)
  }
}
