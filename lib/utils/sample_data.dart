import '../models/ipo.dart';
import '../models/ipo_application.dart';
import '../models/ledger_entry.dart';
import '../models/person.dart';

class SampleData {
  /// Clean slate default
  static List<Person> get initialPeople => naradaPeople;

  /// The user's real family/syndicate members imported from Narada
  static List<Person> get naradaPeople => [
        Person(
          id: '8cf283aa-3ad7-445a-8722-0b2bd9e132b0',
          name: 'Prathamesh Govind Suryawanshi',
          pan: 'MMEPS3478L',
          phone: '8080044997',
          upiId: 'prathameshsuryawanshi51@oksbi',
          bankName: 'Canara Bank',
          accountNumber: '2091',
          isSelf: true,
        ),
        Person(
          id: '0b73432b-bc88-4bde-9fd1-c22b27e0ebda',
          name: 'Sarang Gorakh Phasale',
          pan: 'EYHPP5611K',
          phone: '7249645243',
          upiId: 'sarangphasale@okicici',
        ),
        Person(
          name: 'Aryan Sunil Suryawanshi',
          pan: 'UNRPS7862E',
        ),
        Person(
          name: 'Ritesh Mahendra Wankhede',
          pan: 'AGNPW9609C',
        ),
        Person(
          name: 'Vinay Dattatray Khairnar',
          pan: 'HHTPK9732C',
        ),
        Person(
          name: 'Dhanshri Govind Suryawanshi',
          pan: 'PLDPS5929F',
        ),
        Person(
          name: 'Varun Prakash Kanade',
          pan: 'IAIPK8933G',
        ),
        Person(
          name: 'Priyanka Raghunath Ghuge',
          pan: 'DULPG9849D',
        ),
        Person(
          name: 'Kunal Raju Warke',
          pan: 'AHDPW5924D',
        ),
      ];

  /// Real market IPOs currently open / scheduled in India
  static List<Ipo> get initialIpos {
    final now = DateTime.now();
    return [
      // 1. OPEN IPOs (Bidding currently in progress)
      Ipo(
        id: 'real-ipo-1',
        naradaId: 1084,
        name: 'Hero Motors Ltd',
        symbol: 'HEROMOTO',
        lotSize: 35,
        pricePerShare: 412, // Lot Cost: ₹14,420
        issueSizeCrores: 900.0,
        category: IpoCategory.mainboard,
        openDate: now.subtract(const Duration(days: 1)),
        closeDate: now.add(const Duration(days: 2)),
        allotmentDate: now.add(const Duration(days: 4)),
        listingDate: now.add(const Duration(days: 7)),
        registrar: RegistrarType.linkIntime,
        gmp: 52,
        gmpTrend: GmpTrend.up,
        retailSubscription: 18.4,
        qibSubscription: 32.6,
        niiSubscription: 21.2,
        totalSubscription: 24.1,
        notes: 'Mainboard Auto ancillary public issue',
      ),
      Ipo(
        id: 'real-ipo-3',
        naradaId: 1088,
        name: 'SS Retail Ltd',
        symbol: 'SSRETAIL',
        lotSize: 35,
        pricePerShare: 424.0, // Lot Cost: ₹14,840
        minPrice: 403.0,
        maxPrice: 424.0,
        issueSizeCrores: 500.0, // 500 Cr issue size
        category: IpoCategory.mainboard,
        openDate: DateTime(2026, 9, 16, 10, 0),
        closeDate: DateTime(2026, 9, 18, 17, 0),
        allotmentDate: DateTime(2026, 9, 21, 18, 0),
        listingDate: DateTime(2026, 9, 24, 10, 0),
        registrar: RegistrarType.kfintech,
        gmp: 124.0,
        gmpTrend: GmpTrend.up,
        retailSubscription: 9.2,
        qibSubscription: 14.5,
        niiSubscription: 11.8,
        totalSubscription: 3.24,
        notes: 'Retail & Consumer goods franchise',
      ),
      Ipo(
        id: 'real-ipo-manika',
        naradaId: 1079,
        name: 'Manika Plastech Ltd',
        symbol: 'MANIKA',
        lotSize: 348,
        pricePerShare: 43.0, // Lot Cost: ₹14,964
        minPrice: 40.0,
        maxPrice: 43.0,
        issueSizeCrores: 125.5,
        category: IpoCategory.mainboard,
        openDate: DateTime(2026, 9, 11, 10, 0),
        closeDate: DateTime(2026, 9, 16, 17, 0), // Closed yesterday! Awaiting allotment today
        allotmentDate: DateTime(2026, 9, 17, 20, 0), // Allotment today! Stays in Open/Closed tab
        listingDate: DateTime(2026, 9, 21, 10, 0),
        registrar: RegistrarType.bigshare,
        gmp: 2.0,
        gmpTrend: GmpTrend.stable,
        retailSubscription: 29.46,
        totalSubscription: 29.46,
        notes: 'Plastech packaging solutions - Bidding closed yesterday, awaiting allotment today',
      ),

      // 2. CLOSED IPO (Bidding closed, but awaiting allotment -> Stays in Open/Closed tab just like Narada!)
      Ipo(
        id: 'real-ipo-veegaland',
        name: 'Veegaland Developers Ltd',
        symbol: 'VEEGALAND',
        lotSize: 150,
        pricePerShare: 96, // Lot Cost: ₹14,400
        issueSizeCrores: 180.0,
        category: IpoCategory.mainboard,
        openDate: now.subtract(const Duration(days: 4)),
        closeDate: now.subtract(const Duration(days: 1)),
        allotmentDate: now.add(const Duration(days: 2)), // Allotment in 2 days
        listingDate: now.add(const Duration(days: 5)),
        registrar: RegistrarType.kfintech,
        gmp: 16.0,
        gmpTrend: GmpTrend.up,
        retailSubscription: 34.2,
        totalSubscription: 38.6,
        notes: 'Infrastructure and developers - Bidding closed, awaiting allotment',
      ),

      // 3. ALLOTTED IPO (Allotment out, listing upcoming -> Appears in Allotted/Listed tab)
      Ipo(
        id: 'real-ipo-rentomojo',
        naradaId: 1066,
        name: 'Rentomojo Ltd',
        symbol: 'RENTOMOJO',
        lotSize: 37,
        pricePerShare: 404, // Lot Cost: ₹14,948
        issueSizeCrores: 450.0,
        category: IpoCategory.mainboard,
        openDate: now.subtract(const Duration(days: 7)),
        closeDate: now.subtract(const Duration(days: 4)),
        allotmentDate: now.subtract(const Duration(days: 1)), // Allotment finalized yesterday!
        listingDate: now.add(const Duration(days: 1)), // Listing tomorrow!
        registrar: RegistrarType.linkIntime,
        gmp: 103.0,
        gmpTrend: GmpTrend.up,
        retailSubscription: 72.88,
        totalSubscription: 72.88,
        notes: 'Furniture & consumer tech rentals - Allotment finalized',
      ),

      // 4. LISTED IPOs (Listed within the last 5 days -> In Allotted/Listed with "Listed on" and "Current Price")
      Ipo(
        id: 'narada-1061',
        naradaId: 1061,
        name: 'Kanohar Electricals Limited',
        symbol: 'KANOHAR',
        lotSize: 23,
        pricePerShare: 632.0, // Issue Price: ₹632.0
        issueSizeCrores: 320.0,
        category: IpoCategory.mainboard,
        openDate: now.subtract(const Duration(days: 8)),
        closeDate: now.subtract(const Duration(days: 6)),
        allotmentDate: now.subtract(const Duration(days: 4)),
        listingDate: now.subtract(const Duration(days: 2)), // Listed 2 days ago (within 5 days!)
        registrar: RegistrarType.linkIntime,
        gmp: 119.5,
        listingPrice: 685.5, // Narada official listing price
        currentPrice: 751.5, // Narada current market price (+₹119.5 / +18.9%)
        retailSubscription: 42.1,
        totalSubscription: 45.8,
        notes: 'Electrical transformers & substation equipment - Listed on exchange',
      ),
      Ipo(
        id: 'narada-1062',
        naradaId: 1062,
        name: 'Glass Wall Systems (India) Limited',
        symbol: 'GLASSWALL',
        lotSize: 75,
        pricePerShare: 182.0, // Issue Price: ₹182.0
        issueSizeCrores: 240.0,
        category: IpoCategory.mainboard,
        openDate: now.subtract(const Duration(days: 8)),
        closeDate: now.subtract(const Duration(days: 6)),
        allotmentDate: now.subtract(const Duration(days: 4)),
        listingDate: now.subtract(const Duration(days: 2)), // Listed 2 days ago (within 5 days!)
        registrar: RegistrarType.kfintech,
        gmp: 32.85,
        listingPrice: 194.0, // Narada official listing price
        currentPrice: 214.85, // Narada current market price (+₹32.85 / +18.0%)
        retailSubscription: 28.3,
        totalSubscription: 31.4,
        notes: 'Architectural facade systems - Listed on exchange',
      ),
      Ipo(
        id: 'real-ipo-arcil',
        naradaId: 1065,
        name: 'Asset Reconstruction Co (India) Ltd',
        symbol: 'ARCIL',
        lotSize: 100,
        pricePerShare: 139, // Issue Price: ₹139
        issueSizeCrores: 1150.0,
        category: IpoCategory.mainboard,
        openDate: now.subtract(const Duration(days: 8)),
        closeDate: now.subtract(const Duration(days: 5)),
        allotmentDate: now.subtract(const Duration(days: 4)),
        listingDate: now.subtract(const Duration(days: 2)), // Listed 2 days ago (within 5 days!)
        registrar: RegistrarType.linkIntime,
        gmp: 10.25,
        currentPrice: 151.5, // Current market price (+₹12.5 / +9.0%)
        listingPrice: 149.25,
        retailSubscription: 20.1,
        totalSubscription: 20.1,
        notes: 'Asset reconstruction and distress turnaround - Listed on exchange',
      ),
      Ipo(
        id: 'real-ipo-lcc',
        naradaId: 1064,
        name: 'LCC Projects Ltd',
        symbol: 'LCCPROJECT',
        lotSize: 100,
        pricePerShare: 146, // Issue Price: ₹146
        issueSizeCrores: 210.0,
        category: IpoCategory.mainboard,
        openDate: now.subtract(const Duration(days: 9)),
        closeDate: now.subtract(const Duration(days: 6)),
        allotmentDate: now.subtract(const Duration(days: 5)),
        listingDate: now.subtract(const Duration(days: 3)), // Listed 3 days ago (within 5 days!)
        registrar: RegistrarType.bigshare,
        gmp: 43.0,
        currentPrice: 189.0, // Current market price (+₹43.0 / +29.5%)
        listingPrice: 189.0,
        retailSubscription: 49.57,
        totalSubscription: 49.57,
        notes: 'EPC civil infrastructure projects - Listed on exchange',
      ),

      // 5. EXPIRED LISTED IPO (Listed 12 days ago -> Excluded from Allotted/Listed because > 5 days!)
      Ipo(
        id: 'real-ipo-oldlisted',
        name: 'Omni Tech Solutions Ltd',
        symbol: 'OMNITECH',
        lotSize: 50,
        pricePerShare: 210,
        issueSizeCrores: 150.0,
        category: IpoCategory.mainboard,
        openDate: now.subtract(const Duration(days: 20)),
        closeDate: now.subtract(const Duration(days: 17)),
        allotmentDate: now.subtract(const Duration(days: 15)),
        listingDate: now.subtract(const Duration(days: 12)), // Listed 12 days ago (> 5 days!)
        registrar: RegistrarType.linkIntime,
        currentPrice: 245.0,
        notes: 'Historical listed issue - Past 5-day retention window',
      ),

      // 6. UPCOMING IPOs
      Ipo(
        id: 'real-ipo-2',
        naradaId: 1089,
        name: 'National Stock Exchange (NSE)',
        symbol: 'NSE',
        lotSize: 8,
        pricePerShare: 1785.0, // Lot Cost: ₹14,280
        minPrice: 1700.0,
        maxPrice: 1785.0,
        issueSizeCrores: 22569.0,
        category: IpoCategory.mainboard,
        openDate: DateTime(2026, 9, 17, 10, 0), // Opened today!
        closeDate: DateTime(2026, 9, 21, 17, 0),
        allotmentDate: DateTime(2026, 9, 22, 18, 0),
        listingDate: DateTime(2026, 9, 24, 10, 0),
        registrar: RegistrarType.linkIntime,
        gmp: 142.0,
        gmpTrend: GmpTrend.up,
        retailSubscription: 0.27,
        qibSubscription: 0.0,
        niiSubscription: 0.0,
        totalSubscription: 0.27,
        notes: 'High demand market infrastructure IPO - Open for bidding',
      ),
      Ipo(
        id: 'real-ipo-4',
        naradaId: 1085,
        name: 'Sonaselection India Ltd',
        symbol: 'SONASEL',
        lotSize: 50,
        pricePerShare: 298, // Lot Cost: ₹14,900
        issueSizeCrores: 45.0,
        category: IpoCategory.mainboard,
        openDate: now.add(const Duration(days: 1)),
        closeDate: now.add(const Duration(days: 4)),
        allotmentDate: now.add(const Duration(days: 7)),
        listingDate: now.add(const Duration(days: 10)),
        registrar: RegistrarType.bigshare,
        gmp: 32,
        retailSubscription: 6.8,
        qibSubscription: 12.0,
        niiSubscription: 8.4,
        totalSubscription: 9.1,
        notes: 'Electronics and smart home manufacturer',
      ),
    ];
  }

  static List<IpoApplication> get initialApplications => [];
  static List<LedgerEntry> get initialLedgerEntries => [];
}
