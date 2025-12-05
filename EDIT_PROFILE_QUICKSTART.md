# 🚀 Edit Profile Feature - Quick Start

## Setup (1 Step)

### Create Avatars Bucket:
1. Supabase Dashboard → **Storage** → **New Bucket**
2. Name: `avatars`
3. Toggle **Public** to ON
4. Click **Create**

✅ Done!

---

## How to Use

### Access Edit Profile:
```
Home Screen → Tap Avatar Icon → Select "Edit Profile"
```

### Edit & Save:
1. **Change Avatar**: Tap camera icon or "Change Avatar" button
2. **Edit Name**: Update full name (required)
3. **Edit Phone**: Update phone number (optional)
4. **Save**: Tap "Save Changes"

### Automatic Updates:
- ✅ Avatar shows immediately in user menu
- ✅ Name shows in welcome message
- ✅ No manual refresh needed

---

## File Structure

```
lib/features/auth/
├── data/
│   ├── services/
│   │   └── avatar_upload_service.dart     # NEW
│   └── repositories/
│       └── profile_repository.dart         # (existing, updateProfile method)
├── providers/
│   └── profile_provider.dart               # UPDATED (added ProfileUpdateController)
└── presentation/
    └── screens/
        └── edit_profile_page.dart          # NEW

lib/core/config/
└── router_config.dart                      # UPDATED (added /auth/edit-profile route)

lib/features/home/
└── presentation/
    └── screens/
        └── home_screen.dart                # UPDATED (added Edit Profile menu + avatar display)

supabase_avatars_storage_setup.sql          # NEW
EDIT_PROFILE_GUIDE.md                       # NEW (full documentation)
```

---

## State Management

### Update Flow:
```
User saves → ProfileUpdateController.updateProfile()
           → ProfileRepository.updateProfile()
           → Supabase 'profiles' table updated
           → ref.invalidate(currentUserProfileProvider)
           → Profile refetches
           → Home Screen auto-updates
```

### Key Providers:
- `currentUserProfileProvider` - FutureProvider for user profile
- `profileUpdateControllerProvider` - StateNotifier for updates
- `profileRepositoryProvider` - Repository instance

---

## Security

### RLS Policies:
- ✅ Users can update own `full_name` and `avatar_url` only
- ❌ Users CANNOT update `role` or `is_banned`
- ✅ Storage policies enforce user folder isolation

### Storage Structure:
```
avatars/{userId}/avatar_{timestamp}.jpg
```

---

## Troubleshooting

### Avatar upload fails:
- Check bucket exists and is public
- Verify user is logged in

### Avatar doesn't update:
- Check provider is invalidated after save
- Clear app cache and restart

### Permission denied:
- Run `supabase_avatars_storage_setup.sql`
- Verify user is authenticated

---

## Testing

```
✓ Create avatars bucket
✓ Login to app
✓ Go to Edit Profile
✓ Upload avatar
✓ Change name
✓ Save
✓ Verify avatar shows in menu
✓ Verify name shows on home
```

---

## Next Steps

1. ✅ Create avatars bucket
2. ✅ Test avatar upload
3. ✅ Test profile update
4. ✅ Verify auto-refresh works

---

**For detailed documentation, see:** `EDIT_PROFILE_GUIDE.md`
