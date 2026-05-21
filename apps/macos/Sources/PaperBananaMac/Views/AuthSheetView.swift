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

      Picker("模式", selection: modeBinding) {
        Text("登录").tag(AuthMode.signIn.id)
        Text("注册").tag(AuthMode.signUp.id)
      }
      .pickerStyle(.segmented)

      Form {
        TextField("邮箱", text: $model.authEmail)
        SecureField("密码", text: $model.authPassword)
        if model.authMode == .signUp {
          TextField("昵称", text: $model.authName)
        }
      }
      .formStyle(.grouped)

      if !model.authError.isEmpty {
        Text(model.authError)
          .foregroundStyle(.red)
      }

      HStack {
        Text("登录请求会通过 Sealos 网关处理。")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("取消") {
          dismiss()
        }
        Button(model.authMode == .signUp ? "注册" : "登录") {
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
