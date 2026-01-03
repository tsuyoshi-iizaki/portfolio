// RevenueCat entitlement ID (kept as-is, can be overridden via --dart-define)
const entitlementID =
    String.fromEnvironment('ENTITLEMENT_ID', defaultValue: 'TSPプレミアムプラン');

// RevenueCat API keys (provide via --dart-define)
const appleApiKey = String.fromEnvironment('APPLE_API_KEY', defaultValue: '');
const googleApiKey = String.fromEnvironment('GOOGLE_API_KEY', defaultValue: '');
const amazonApiKey =
    String.fromEnvironment('AMAZON_API_KEY', defaultValue: 'amazon_api_key');

// Cloud Functions endpoint (provide via --dart-define)
const String functionUrl =
    String.fromEnvironment('FUNCTION_URL', defaultValue: '');

// AdMob unit IDs (provide via --dart-define)
const googleInterstitialAdsAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: '');
const googleInterstitialAdsIos =
    String.fromEnvironment('ADMOB_INTERSTITIAL_IOS', defaultValue: '');
const googleAdsBannerAndroid =
    String.fromEnvironment('ADMOB_BANNER_ANDROID', defaultValue: '');
const googleAdsBannerIos =
    String.fromEnvironment('ADMOB_BANNER_IOS', defaultValue: '');

// App Store URL
const appStoreUrl = 'https://apps.apple.com/jp/app/id6473671662';
