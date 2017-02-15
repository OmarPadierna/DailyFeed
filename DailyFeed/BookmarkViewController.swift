//
//  BookmarkViewController.swift
//  DailyFeed
//
//  Created by TrianzDev on 09/02/17.
//  Copyright © 2017 trianz. All rights reserved.
//

import UIKit
import RealmSwift
import CoreSpotlight
import MobileCoreServices

class BookmarkViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var bookmarkCollectionView: UICollectionView!

    var newsItems: Results<DailyFeedRealmModel>!
    
    var notificationToken: NotificationToken? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        bookmarkCollectionView?.register(UINib(nibName: "BookmarkItemsCell", bundle: nil),
                                         forCellWithReuseIdentifier: "BookmarkItemsCell")
        observeDatabase()
    }

    func observeDatabase() {
        //Realm Shared DB Setup
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.trianz.DailyFeed.today")
        let realmURL = container?.appendingPathComponent("db.realm")
        var config = Realm.Configuration()
        config.fileURL = realmURL
        config.schemaVersion = 3
        config.migrationBlock = { migration, oldSchemaVersion in
            if (oldSchemaVersion < 3) {
                
            }
        }
        Realm.Configuration.defaultConfiguration = config
        let realm = try! Realm()
        newsItems = realm.objects(DailyFeedRealmModel.self)
        
        notificationToken = newsItems.addNotificationBlock { [weak self] (changes: RealmCollectionChange) in
            guard let collectionview = self?.bookmarkCollectionView else { return }
            switch changes {
            case .initial:
                collectionview.reloadData()
                break
            case .update( _, let deletions, let insertions, _):
                collectionview.performBatchUpdates({
                    collectionview.deleteItems(at: deletions.map({ IndexPath(row: $0, section: 0) }))
                    _ = deletions.map {
                        self?.deindex(item: $0)
                    }
                    collectionview.insertItems(at: insertions.map({ IndexPath(row: $0, section: 0) }))
                    _ = insertions.map {
                        self?.index(item: $0)
                    }

                }, completion: nil)

                break
            case .error(let error):
                fatalError("\(error)")
                break
            }
        }
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "bookmarkSourceSegue" {
            if let vc = segue.destination as? NewsDetailViewController {
            guard let cell = sender as? UICollectionViewCell else { return }
            guard let indexpath = self.bookmarkCollectionView.indexPath(for: cell) else { return }
            vc.receivedNewsItem = newsItems[indexpath.row]
            }
        }
    }
    
    deinit {
        notificationToken?.stop()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: - CollectionView Delegate Methods
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return newsItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let newsCell = collectionView.dequeueReusableCell(withReuseIdentifier: "BookmarkItemsCell", for: indexPath) as? BookmarkItemsCell
        newsCell?.newsArticleTitleLabel.text = newsItems[indexPath.row].title
        newsCell?.newsArticleAuthorLabel.text = newsItems[indexPath.row].author
        newsCell?.newsArticleTimeLabel.text = newsItems[indexPath.row].publishedAt.dateFromTimestamp?.relativelyFormatted(short: true)
        newsCell?.newsArticleImageView.downloadedFromLink(newsItems[indexPath.row].urlToImage)
        newsCell?.cellTapped = { cell in
            if let cellToDelete = self.bookmarkCollectionView.indexPath(for: cell)?.row {
            let item = self.newsItems[cellToDelete]
            let realm = try! Realm()
                try! realm.write {
                    realm.delete(item)
                }
                
            }
        }
        return newsCell!
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: bookmarkCollectionView.bounds.width, height: bookmarkCollectionView.bounds.height / 5)
    }
    
     func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath)
        self.performSegue(withIdentifier: "bookmarkSourceSegue", sender: cell)
    }
    
    
    // MARK: - CoreSpotlight Indexing and deindexing methods
    
    func index(item: Int) {
        let project = newsItems[item]
        
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        attributeSet.title = project.title
        attributeSet.contentDescription = project.author
        
        let item = CSSearchableItem(uniqueIdentifier: "\(item)", domainIdentifier: "com.trianz", attributeSet: attributeSet)
        item.expirationDate = Date.distantFuture
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("Indexing error: \(error.localizedDescription)")
            } else {
                print("Search item successfully indexed!")
            }
        }
    }
    
    func deindex(item: Int) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["\(item)"]) { error in
            if let error = error {
                print("Deindexing error: \(error.localizedDescription)")
            } else {
                print("Search item successfully removed!")
            }
        }
    }
    
}
