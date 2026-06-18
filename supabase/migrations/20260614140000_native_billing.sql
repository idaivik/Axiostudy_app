-- Native billing migration: replace Razorpay columns on `profiles` with
-- store-agnostic columns used by Google Play Billing + Apple StoreKit (via
-- RevenueCat). The RevenueCat app_user_id IS the profile id, so no separate
-- "customer id" column is needed.

alter table public.profiles
  drop column if exists razorpay_customer_id,
  drop column if exists razorpay_subscription_id;

alter table public.profiles
  add column if not exists subscription_platform text,   -- 'play_store' | 'app_store'
  add column if not exists store_product_id text,         -- store product identifier
  add column if not exists store_transaction_id text;     -- latest store transaction id

comment on column public.profiles.subscription_platform is
  'Store that processed the subscription: play_store | app_store.';
comment on column public.profiles.store_product_id is
  'Store product identifier of the active subscription (e.g. axio_premium).';
comment on column public.profiles.store_transaction_id is
  'Most recent store transaction id for the subscription.';
