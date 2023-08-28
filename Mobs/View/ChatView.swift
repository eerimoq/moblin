//
//  ChatView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-08-28.
//

import SwiftUI

struct LineView: View {
    var user: String
    var message: String
    
    var body: some View {
        HStack {
            Text(user)
                .frame(width: 40, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding([.leading], 5)
            Text(message)
                .padding([.trailing], 5)
        }
        .padding(0)
        .font(.system(size: 14))
        .background(.black)
        .foregroundColor(.white)
        .cornerRadius(5)
    }
}

struct ChatView: View {
    var posts: [Post]
    
    var body: some View {
        VStack(alignment: .leading) {
            ForEach(posts, id: \.self) {post in
                LineView(user: post.user, message: post.message)
            }
        }
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView(posts: [
            Post(user: "Foo", message: "bar fe fe ef"),
            Post(user: "Foofowkokwef", message: "barwef wef we fe fe ef")
        ])
    }
}
